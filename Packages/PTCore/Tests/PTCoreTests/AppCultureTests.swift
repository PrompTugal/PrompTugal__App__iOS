import Foundation
import Testing
@testable import PTCore

@Suite("App culture", .serialized)
struct AppCultureTests {
    private func defaults() -> UserDefaults {
        let suite = "AppCultureTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("There are 21 cultures, English first, with unique ids")
    func list() {
        #expect(AppCulture.all.count == 21)
        #expect(AppCulture.all.first?.id == "en-GB")
        #expect(Set(AppCulture.all.map(\.id)).count == 21)
        for id in ["pt-PT", "pt-BR", "de-CH", "es-AR", "fr-CA", "zh-Hans", "ja-JP", "ko-KR", "hi-IN", "ar"] {
            #expect(AppCulture.all.contains { $0.id == id }, "missing \\(id)")
        }
    }

    @Test("Each culture is named in its own language")
    func names() {
        #expect(AppCulture.culture("de-CH").name == "Deutsch (Schweiz)")
        #expect(AppCulture.culture("pt-BR").name == "Português (Brasil)")
        #expect(AppCulture.culture("ja-JP").name == "日本語")
        #expect(AppCulture.culture("en-GB").name == "English")
    }

    @Test("The default is English, whatever the saved value or the device")
    func defaultIsEnglish() {
        let store = defaults()
        AppCulture.start(defaults: store)
        #expect(AppCulture.currentID == "en-GB")
        store.set("xx-YY", forKey: AppCulture.storageKey)
        AppCulture.start(defaults: store)
        #expect(AppCulture.currentID == "en-GB")
    }

    @Test("A choice is kept on the device and can go back to English")
    func choose() {
        let store = defaults()
        AppCulture.select("pt-BR", defaults: store)
        #expect(AppCulture.current.id == "pt-BR")
        #expect(store.string(forKey: AppCulture.storageKey) == "pt-BR")
        AppCulture.start(defaults: store)
        #expect(AppCulture.currentID == "pt-BR")
        AppCulture.select("en-GB", defaults: store)
        #expect(AppCulture.isEnglish)
        AppCulture.select("not-a-culture", defaults: store)
        #expect(AppCulture.isEnglish)
    }

    @Test("Arabic is right to left, the others are not")
    func direction() {
        #expect(AppCulture.culture("ar").isRightToLeft)
        #expect(!AppCulture.culture("de-CH").isRightToLeft)
        #expect(!AppCulture.culture("ja-JP").isRightToLeft)
    }

    @Test("Times follow the chosen culture and stay in Lisbon time")
    func times() {
        let store = defaults()
        let noon = Lisbon.instant(day: "2026-11-10", clock: "14:05")!
        AppCulture.select("en-US", defaults: store)
        #expect(Lisbon.timeLabel(noon).contains("PM"))
        AppCulture.select("de-DE", defaults: store)
        #expect(Lisbon.timeLabel(noon).contains("14:05"))
        AppCulture.select("en-GB", defaults: store)
    }
}
