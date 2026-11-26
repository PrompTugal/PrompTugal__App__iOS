import Foundation
import ObjectiveC
import SwiftUI

/// A culture: a language and a region (en-GB, pt-BR, de-CH), the model of send.sgraph.ai.
public struct Culture: Identifiable, Hashable, Sendable {
    /// BCP 47 id, e.g. "en-GB", "zh-Hans".
    public let id: String
    /// The culture's name in its own language ("Deutsch (Schweiz)").
    public let name: String
    /// What the globe button shows: the language ("EN", "PT"), with the region where a language has more than one culture
    /// ("PT-BR", "DE-CH"). English (en-GB) is plain "EN".
    public let code: String

    public var locale: Locale { Locale(identifier: id) }
    public var language: String { String(id.prefix { $0 != "-" }) }
    public var isRightToLeft: Bool { ["ar", "he", "fa", "ur"].contains(language) }
    public var layoutDirection: LayoutDirection { isRightToLeft ? .rightToLeft : .leftToRight }
}

/// The app's own language: English (en-GB) or Portuguese (pt-PT), nothing else (Dinis, 26 Nov 2026).
///
/// With no choice saved, the app follows the device: the first of the device's languages that is Portuguese (any
/// region) gives pt-PT, the first that is English gives en-GB, and a device with neither gets English. This is how iOS
/// itself picks among an app's localisations. A saved choice (the language button, when the app shows one) wins.
/// The choice lives in this device's UserDefaults only and is never sent anywhere.
public enum AppCulture {
    public static let storageKey = "app.culture"
    public static let english = "en-GB"
    public static let portuguese = "pt-PT"

    /// The two cultures, English first ("back to English" is the first row).
    public static let all: [Culture] = [
        Culture(id: "en-GB", name: "English", code: "EN"),
        Culture(id: "pt-PT", name: "Português", code: "PT"),
    ]

    public static func culture(_ id: String) -> Culture { all.first { $0.id == id } ?? all[0] }

    /// The chosen culture's id. Read by the Bundle override on every lookup, so it is a plain cached value:
    /// set it only with `start`, `select(_:)` or `followDevice()`.
    nonisolated(unsafe) private(set) static var currentID: String = english

    public static var current: Culture { culture(currentID) }
    public static var locale: Locale { current.locale }
    public static var isEnglish: Bool { currentID == english }

    /// True when no choice is saved and the app follows the device's language.
    public static func followsDevice(defaults: UserDefaults = .standard) -> Bool {
        saved(defaults) == nil
    }

    /// The culture for a device's preferred languages (BCP 47, most preferred first): the first Portuguese or English
    /// entry decides; neither gives English.
    public static func resolve(device languages: [String]) -> String {
        for raw in languages {
            let language = raw.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? ""
            if language == "pt" { return portuguese }
            if language == "en" { return english }
        }
        return english
    }

    /// Reads the saved choice or follows the device (call once at launch, before any view reads a string) and installs
    /// the Bundle override. `device` is for tests; by default the device's own list is read.
    public static func start(defaults: UserDefaults = .standard, device: [String]? = nil) {
        if let saved = saved(defaults) {
            currentID = saved
            pin(saved, defaults: defaults)
        } else {
            // A culture saved by an older build that is no longer offered (de-DE, ja-JP, ...) is dropped: follow the device.
            defaults.removeObject(forKey: storageKey)
            // Builds up to v0.4.127 pinned AppleLanguages to the app's culture on every launch; that override would keep
            // the device's language out for good, so it goes.
            defaults.removeObject(forKey: appleLanguages)
            currentID = resolve(device: device ?? deviceLanguages())
        }
        LocalizedBundle.install()
    }

    /// Chooses a culture (the person's tap). The screens rebuild when `@AppStorage(AppCulture.storageKey)` changes.
    public static func select(_ id: String, defaults: UserDefaults = .standard) {
        guard all.contains(where: { $0.id == id }) else { return }
        currentID = id
        defaults.set(id, forKey: storageKey)
        pin(id, defaults: defaults)
    }

    /// Forgets the choice: the app follows the device again.
    public static func followDevice(defaults: UserDefaults = .standard, device: [String]? = nil) {
        defaults.removeObject(forKey: storageKey)
        defaults.removeObject(forKey: appleLanguages)
        currentID = resolve(device: device ?? deviceLanguages())
    }

    // MARK: Private

    private static let appleLanguages = "AppleLanguages"

    private static func saved(_ defaults: UserDefaults) -> String? {
        guard let id = defaults.string(forKey: storageKey), all.contains(where: { $0.id == id }) else { return nil }
        return id
    }

    /// The system reads `AppleLanguages` at launch: for an explicit choice, pin it so what the system itself localises
    /// follows the app's choice and not the device's, on every launch after this.
    private static func pin(_ id: String, defaults: UserDefaults) {
        defaults.set([id], forKey: appleLanguages)
    }

    /// The device's languages, not this app's override (which an older build may have pinned): the global domain,
    /// else `Locale.preferredLanguages`.
    static func deviceLanguages() -> [String] {
        let global = CFPreferencesCopyValue(appleLanguages as CFString, kCFPreferencesAnyApplication,
                                            kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String]
        if let global, !global.isEmpty { return global }
        return Locale.preferredLanguages
    }
}

// MARK: - Bundle override

/// Makes `String(localized:)`, `NSLocalizedString` and the packages' catalogs (`bundle: .module`) read the chosen culture's
/// strings instead of the device's. It swaps `Bundle.localizedString(forKey:value:table:)` once.
enum LocalizedBundle {
    nonisolated(unsafe) private static var installed = false
    nonisolated(unsafe) private static var cache: [String: Bundle?] = [:]
    private static let lock = NSLock()

    static func install() {
        lock.lock(); defer { lock.unlock() }
        guard !installed else { return }
        installed = true
        let original = #selector(Bundle.localizedString(forKey:value:table:))
        let replacement = #selector(Bundle.pt_localizedString(forKey:value:table:))
        guard let a = class_getInstanceMethod(Bundle.self, original),
              let b = class_getInstanceMethod(Bundle.self, replacement) else { return }
        method_exchangeImplementations(a, b)
    }

    /// The `.lproj` bundle of `bundle` for the chosen culture, or nil to use the bundle as it is (English, or no match).
    static func resource(for bundle: Bundle) -> Bundle? {
        let id = AppCulture.currentID
        // Never redirect inside an lproj we already picked.
        guard !bundle.bundlePath.hasSuffix(".lproj") else { return nil }
        let key = bundle.bundlePath + "|" + id
        lock.lock(); defer { lock.unlock() }
        if let hit = cache[key] { return hit }
        let match = Bundle.preferredLocalizations(from: bundle.localizations, forPreferences: [id]).first
        var found: Bundle?
        if let match, let path = bundle.path(forResource: match, ofType: "lproj") { found = Bundle(path: path) }
        cache[key] = found
        return found
    }
}

extension Bundle {
    /// After the swap this is the original implementation, and `localizedString` is this one.
    @objc fileprivate func pt_localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let localized = LocalizedBundle.resource(for: self) {
            // `localized` is an lproj: its own lookup is the original (the swapped one skips lproj bundles).
            return localized.pt_localizedString(forKey: key, value: value, table: tableName)
        }
        return pt_localizedString(forKey: key, value: value, table: tableName)
    }
}

// MARK: - SwiftUI

extension View {
    /// Applies the chosen culture to a screen: its locale (dates, numbers, the catalogs) and its layout direction
    /// (right to left for Arabic).
    public func appCulture(_ id: String) -> some View {
        let culture = AppCulture.culture(id)
        return environment(\.locale, culture.locale)
            .environment(\.layoutDirection, culture.layoutDirection)
    }
}
