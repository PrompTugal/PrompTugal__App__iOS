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

/// The app's own language setting. The default is always English (en-GB): the app does NOT follow the device's language
/// until the reader chooses one. The choice lives in this device's UserDefaults only and is never sent anywhere.
public enum AppCulture {
    public static let storageKey = "app.culture"
    public static let english = "en-GB"

    /// The 21 cultures, English first ("back to English" is the first row).
    public static let all: [Culture] = [
        Culture(id: "en-GB", name: "English", code: "EN"),
        Culture(id: "en-US", name: "English (United States)", code: "EN-US"),
        Culture(id: "pt-PT", name: "Português (Portugal)", code: "PT-PT"),
        Culture(id: "pt-BR", name: "Português (Brasil)", code: "PT-BR"),
        Culture(id: "de-DE", name: "Deutsch (Deutschland)", code: "DE-DE"),
        Culture(id: "de-CH", name: "Deutsch (Schweiz)", code: "DE-CH"),
        Culture(id: "es-ES", name: "Español (España)", code: "ES-ES"),
        Culture(id: "es-AR", name: "Español (Argentina)", code: "ES-AR"),
        Culture(id: "es-MX", name: "Español (México)", code: "ES-MX"),
        Culture(id: "fr-FR", name: "Français (France)", code: "FR-FR"),
        Culture(id: "fr-CA", name: "Français (Canada)", code: "FR-CA"),
        Culture(id: "it-IT", name: "Italiano", code: "IT"),
        Culture(id: "nl-NL", name: "Nederlands", code: "NL"),
        Culture(id: "pl-PL", name: "Polski", code: "PL"),
        Culture(id: "hr-HR", name: "Hrvatski", code: "HR"),
        Culture(id: "ro-RO", name: "Română", code: "RO"),
        Culture(id: "zh-Hans", name: "简体中文", code: "ZH"),
        Culture(id: "ja-JP", name: "日本語", code: "JA"),
        Culture(id: "ko-KR", name: "한국어", code: "KO"),
        Culture(id: "hi-IN", name: "हिन्दी", code: "HI"),
        Culture(id: "ar", name: "العربية", code: "AR"),
    ]

    public static func culture(_ id: String) -> Culture { all.first { $0.id == id } ?? all[0] }

    /// The chosen culture's id. Read by the Bundle override on every lookup, so it is a plain cached value:
    /// set it only with `select(_:)`.
    nonisolated(unsafe) private(set) static var currentID: String = english

    public static var current: Culture { culture(currentID) }
    public static var locale: Locale { current.locale }
    public static var isEnglish: Bool { currentID == english }

    /// Reads the saved choice (call once at launch, before any view reads a string) and installs the Bundle override.
    public static func start(defaults: UserDefaults = .standard) {
        let saved = defaults.string(forKey: storageKey) ?? english
        currentID = all.contains { $0.id == saved } ? saved : english
        LocalizedBundle.install()
        rememberForNextLaunch(defaults: defaults)
    }

    /// Chooses a culture (the person's tap). The screens rebuild when `@AppStorage(AppCulture.storageKey)` changes.
    public static func select(_ id: String, defaults: UserDefaults = .standard) {
        guard all.contains(where: { $0.id == id }) else { return }
        currentID = id
        defaults.set(id, forKey: storageKey)
        rememberForNextLaunch(defaults: defaults)
    }

    /// The system reads `AppleLanguages` at launch: pin it to the chosen culture so what the system itself localises
    /// (and Bundle.main's own list) follows the app's choice and not the device's language, on every launch after this.
    private static func rememberForNextLaunch(defaults: UserDefaults) {
        defaults.set([currentID], forKey: "AppleLanguages")
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
