import CoreText
import SwiftUI

/// Logo 3: the F on a tile, then "Lisbon Tech Fringe" in Fraunces with "Fringe" in italic.
struct Wordmark: View {
    @ScaledMetric(relativeTo: .title3) private var size: CGFloat = 20

    var body: some View {
        HStack(spacing: 10) {
            Image("Mark")
                .resizable()
                .frame(width: size * 1.8, height: size * 1.8)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.4, style: .continuous))
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("Lisbon Tech ").font(.custom("FrauncesLTF-SemiBold", size: size, relativeTo: .title3))
                    .foregroundStyle(Palette.ink)
                Text("Fringe").font(.custom("FrauncesLTF-SemiBoldItalic", size: size, relativeTo: .title3))
                    .foregroundStyle(Palette.accent)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lisbon Tech Fringe")
    }

    /// Fraunces (SIL Open Font License, Resources/Fonts/Fraunces-OFL.txt) ships in the app.
    static func registerFonts() {
        for name in ["Fraunces-SemiBold", "Fraunces-SemiBoldItalic"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
