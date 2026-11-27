import PTCore
import SwiftUI

/// PTLocal's strings, from its own String Catalog (Resources/Localizable.xcstrings: English and Portuguese, Portugal).
/// Views and models wrap every reader-facing literal in `LocalText.string("...")`; interpolations become %@. The
/// language follows the app's culture (PTCore's AppCulture), so the in-app choice and the device agree.
enum LocalText {
    static func string(_ key: String.LocalizationValue) -> String {
        if isPortuguese, let bundle = portugueseBundle {
            return String(localized: key, bundle: bundle)
        }
        // English is the catalog's source language: a table the bundle does not have gives back the key itself.
        return String(localized: key, table: "PTLocalSourceEnglish", bundle: .module)
    }

    /// True when the app is showing Portuguese.
    static var isPortuguese: Bool { !AppCulture.isEnglish }

    /// The locale dates and numbers are written in (pt_PT gives "21 nov.", en_GB "21 Nov").
    static var locale: Locale { AppCulture.locale }

    private static let portugueseBundle: Bundle? = {
        for name in ["pt-PT", "pt_PT", "pt"] {
            if let path = Bundle.module.path(forResource: name, ofType: "lproj"), let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }()

    /// IPMA's own warning name in Portuguese, the English one otherwise.
    static func warningType(_ type: String) -> String {
        isPortuguese ? type : (IPMA.warningTypes[type] ?? type)
    }
}

extension Text {
    /// Text whose content is in a set language whatever the interface's (the sites' English, an agenda's
    /// Portuguese), marked so VoiceOver reads it with the right voice.
    init(content: String, language: String = "en") {
        var attributed = AttributedString(content)
        attributed.languageIdentifier = language
        self.init(attributed)
    }
}
