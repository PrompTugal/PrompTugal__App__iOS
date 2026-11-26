import Foundation

/// PTLocal's strings, from its own String Catalog (Resources/Localizable.xcstrings: English and Portuguese, Portugal).
/// Views and models wrap every reader-facing literal in `LocalText.string("...")`; interpolations become %@ / %lld.
enum LocalText {
    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .module)
    }

    /// True when the app is showing Portuguese.
    static var isPortuguese: Bool {
        (Bundle.module.preferredLocalizations.first ?? "en").hasPrefix("pt")
    }

    /// IPMA's own warning name in Portuguese, the English one otherwise.
    static func warningType(_ type: String) -> String {
        isPortuguese ? type : (IPMA.warningTypes[type] ?? type)
    }
}
