import PTCore
import SwiftUI

/// Draws a slide on a fixed 1280×720 canvas and scales it to fit, so the iPad preview, the reader and the
/// external display all show the same layout.
public struct SlideCanvas: View {
    public let slide: DeckSlide
    public let deckTitle: String
    public let position: String
    public let store: DeckStore?

    public init(slide: DeckSlide, deckTitle: String, position: String, store: DeckStore? = nil) {
        self.slide = slide
        self.deckTitle = deckTitle
        self.position = position
        self.store = store
    }

    static let size = CGSize(width: 1280, height: 720)

    public var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / Self.size.width, proxy.size.height / Self.size.height)
            SlideContent(slide: slide, deckTitle: deckTitle, position: position, store: store)
                .frame(width: Self.size.width, height: Self.size.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: Self.size.width * scale, height: Self.size.height * scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(Self.size.width / Self.size.height, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(slide.title). \(slide.body)")
    }
}

struct SlideContent: View {
    let slide: DeckSlide
    let deckTitle: String
    let position: String
    let store: DeckStore?

    var body: some View {
        HStack(alignment: .top, spacing: 48) {
            VStack(alignment: .leading, spacing: 28) {
                Text(deckTitle.uppercased())
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Palette.red)
                Text(slide.title)
                    .font(.system(size: slide.body.isEmpty ? 76 : 52, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.ink)
                    .minimumScaleFactor(0.5)
                if !slide.body.isEmpty {
                    Text(DeckText.attributed(slide.body))
                        .font(.system(size: 30))
                        .foregroundStyle(Palette.ink)
                        .lineSpacing(6)
                        .minimumScaleFactor(0.5)
                }
                Spacer(minLength: 0)
                Text(position)
                    .font(.system(size: 22).monospacedDigit())
                    .foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let image = slide.image {
                DeckImage(url: image, store: store)
                    .frame(width: 480)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
        .padding(64)
        .background(Palette.paper)
    }
}

enum DeckText {
    /// `**bold**` lines to bold text; everything else stays plain and keeps its line breaks.
    static func attributed(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

/// A slide image that is kept on disk once it has been seen, so it shows offline.
public struct DeckImage: View {
    let url: URL
    let store: DeckStore?
    @State private var image: Image?

    public init(url: URL, store: DeckStore?) {
        self.url = url
        self.store = store
    }

    public var body: some View {
        ZStack {
            Palette.paper2
            if let image { image.resizable().scaledToFill() }
        }
        .clipped()
        .task(id: url) { await load() }
    }

    private func load() async {
        let cache = store?.imageCache ?? .standard()
        let key = "img." + url.absoluteString
        var data = cache.load(key: key)
        if data == nil {
            data = try? await (store?.fetch ?? DeckFetchers.live)(url)
            if let data { cache.store(data, key: key) }
        }
        if let data, let ui = UIImage(data: data) { image = Image(uiImage: ui) }
    }
}
