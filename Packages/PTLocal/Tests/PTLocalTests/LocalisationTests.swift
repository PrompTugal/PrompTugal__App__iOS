import Foundation
import Testing
@testable import PTLocal

@Suite("Languages: English and Portuguese (Portugal)")
struct LocalisationTests {
    /// The compiled catalog's table for a language, if the build produced one.
    private func table(_ language: String) -> [String: String]? {
        let bundle = LocalResources.bundle
        guard let path = bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: language)
        else { return nil }
        return NSDictionary(contentsOfFile: path) as? [String: String]
    }

    @Test("The package ships Portuguese (Portugal)")
    func shipsPortuguese() {
        #expect(LocalResources.bundle.localizations.contains("pt-PT"))
    }

    @Test("Portuguese has the screens' titles and keeps every placeholder")
    func portuguese() throws {
        let pt = try #require(table("pt-PT"))
        #expect(pt["Alerts"] == "Alertas")
        #expect(pt["Offline edition"] == "Edição offline")
        #expect(pt["Data sources"] == "Fontes de dados")
        #expect(pt["Live, read %@"] == "Em direto, lido às %@")
        for (key, value) in pt {
            #expect(Self.placeholders(key) == Self.placeholders(value), "\(key)")
        }
    }

    @Test("English is the key itself")
    func english() {
        #expect(LocalText.string("Alerts") == "Alerts" || LocalText.isPortuguese)
        let line = LocalText.string("Saving \(String(describing: 3)) of \(String(describing: 7)) files")
        #expect(line == "Saving 3 of 7 files" || LocalText.isPortuguese)
    }

    static func placeholders(_ text: String) -> Int {
        var count = 0
        var index = text.startIndex
        while let range = text.range(of: "%", range: index..<text.endIndex) {
            let rest = text[range.upperBound...]
            if rest.hasPrefix("%") { index = text.index(after: range.upperBound); continue }
            count += 1
            index = range.upperBound
        }
        return count
    }
}
