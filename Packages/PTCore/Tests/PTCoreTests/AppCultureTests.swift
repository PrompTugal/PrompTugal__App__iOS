import Foundation
import Testing
@testable import PTCore

@Suite("App culture", .serialized)
struct AppCultureTests {
    private func defaults() -> UserDefaults { suite().store }

    private func suite() -> (store: UserDefaults, name: String) {
        let name = "AppCultureTests-\(UUID().uuidString)"
        let store = UserDefaults(suiteName: name)!
        store.removePersistentDomain(forName: name)
        return (store, name)
    }

    /// The pin as this suite holds it. Reading the key through the suite also sees the global and argument domains
    /// (on the simulator AppleLanguages is always set there), so "no pin" is checked in the suite's own domain.
    private func pin(_ name: String, in store: UserDefaults) -> Any? {
        store.persistentDomain(forName: name)?["AppleLanguages"]
    }

    @Test("There are two cultures, English first")
    func list() {
        #expect(AppCulture.all.map(\.id) == ["en-GB", "pt-PT"])
        #expect(AppCulture.culture("pt-PT").name == "Português")
        #expect(AppCulture.culture("en-GB").name == "English")
        #expect(AppCulture.culture("de-DE").id == "en-GB")
    }

    @Test("Any Portuguese gives pt-PT, English or anything else gives en-GB")
    func resolve() {
        #expect(AppCulture.resolve(device: ["pt-PT"]) == "pt-PT")
        #expect(AppCulture.resolve(device: ["pt-BR", "en-GB"]) == "pt-PT")
        #expect(AppCulture.resolve(device: ["pt_AO"]) == "pt-PT")
        #expect(AppCulture.resolve(device: ["en-US", "pt-PT"]) == "en-GB")
        #expect(AppCulture.resolve(device: ["fr-FR", "pt-PT"]) == "pt-PT")
        #expect(AppCulture.resolve(device: ["ja-JP"]) == "en-GB")
        #expect(AppCulture.resolve(device: []) == "en-GB")
    }

    @Test("With no choice the app follows the device and clears the old AppleLanguages pin")
    func followsDevice() {
        let (store, name) = suite()
        store.set(["en-GB"], forKey: "AppleLanguages")
        AppCulture.start(defaults: store, device: ["pt-PT", "en-GB"])
        #expect(AppCulture.currentID == "pt-PT")
        #expect(AppCulture.followsDevice(defaults: store))
        #expect(pin(name, in: store) == nil)
        AppCulture.start(defaults: store, device: ["de-DE"])
        #expect(AppCulture.currentID == "en-GB")
    }

    @Test("A culture saved by an older build that is no longer offered is dropped")
    func staleChoice() {
        let store = defaults()
        store.set("de-DE", forKey: AppCulture.storageKey)
        AppCulture.start(defaults: store, device: ["pt-PT"])
        #expect(AppCulture.currentID == "pt-PT")
        #expect(store.string(forKey: AppCulture.storageKey) == nil)
    }

    @Test("A saved choice wins over the device, is pinned, and can be forgotten")
    func choose() {
        let (store, name) = suite()
        AppCulture.select("en-GB", defaults: store)
        AppCulture.start(defaults: store, device: ["pt-PT"])
        #expect(AppCulture.currentID == "en-GB")
        #expect(!AppCulture.followsDevice(defaults: store))
        #expect(pin(name, in: store) as? [String] == ["en-GB"])
        AppCulture.select("pt-PT", defaults: store)
        #expect(AppCulture.current.id == "pt-PT")
        AppCulture.select("not-a-culture", defaults: store)
        #expect(AppCulture.currentID == "pt-PT")
        AppCulture.followDevice(defaults: store, device: ["en-US"])
        #expect(AppCulture.isEnglish)
        #expect(AppCulture.followsDevice(defaults: store))
        #expect(pin(name, in: store) == nil)
    }

    @Test("Neither culture is right to left")
    func direction() {
        #expect(!AppCulture.culture("en-GB").isRightToLeft)
        #expect(!AppCulture.culture("pt-PT").isRightToLeft)
        #expect(Culture(id: "ar", name: "", code: "").isRightToLeft)
    }

    @Test("Times follow the chosen culture and stay in Lisbon time")
    func times() {
        let store = defaults()
        let afternoon = Lisbon.instant(day: "2026-11-10", clock: "14:05")!
        AppCulture.select("pt-PT", defaults: store)
        let portuguese = Lisbon.timeLabel(afternoon)
        #expect(portuguese.contains("14:05"))
        AppCulture.select("en-GB", defaults: store)
        let english = Lisbon.timeLabel(afternoon)
        #expect(english.contains("14:05"))
    }
}
