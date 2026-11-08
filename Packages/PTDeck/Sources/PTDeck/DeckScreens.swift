import PTCore
import SwiftUI

/// The deck list. Open it with `DeckScreen()`; it brings its own navigation stack.
public struct DeckScreen: View {
    @State private var store: DeckStore

    public init(store: DeckStore? = nil) {
        _store = State(initialValue: store ?? DeckStore())
    }

    public var body: some View {
        NavigationStack {
            DeckListView(store: store)
                .navigationTitle("Decks")
        }
    }
}

public struct DeckListView: View {
    let store: DeckStore

    public init(store: DeckStore) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.phase {
            case .failed(let message) where store.catalog == nil:
                ContentUnavailableView {
                    Label("No decks yet", systemImage: "rectangle.on.rectangle.slash")
                } description: {
                    Text("Decks load once online, then read offline. \(message)")
                } actions: {
                    Button("Try again") { Task { await store.loadCatalog() } }
                }
            default:
                if store.catalog == nil {
                    ProgressView("Loading decks…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    list
                }
            }
        }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { LanguageMenu(store: store) } }
        .task { if store.catalog == nil { await store.loadCatalog() } }
        .refreshable { await store.loadCatalog() }
    }

    private var list: some View {
        List(store.catalog?.decks ?? []) { summary in
            NavigationLink {
                DeckReaderView(store: store, summary: summary)
            } label: {
                HStack(spacing: Space.m) {
                    if let cover = summary.cover {
                        DeckImage(url: cover, store: store)
                            .frame(width: 112, height: 63)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.title.text(in: store.language)).font(Typo.headline)
                        Text(summary.summary.text(in: store.language))
                            .font(Typo.meta).foregroundStyle(Palette.muted).lineLimit(2)
                    }
                }
            }
        }
    }
}

public struct LanguageMenu: View {
    let store: DeckStore

    public init(store: DeckStore) {
        self.store = store
    }

    public var body: some View {
        @Bindable var store = store
        Picker("Language", selection: $store.language) {
            ForEach(DeckLanguage.allCases) { Text($0.displayName).tag($0) }
        }
        .pickerStyle(.menu)
    }
}

/// Swipe through the slides of one deck. On iPad there is a Present button; on iPhone this is the reader only.
public struct DeckReaderView: View {
    let store: DeckStore
    let summary: DeckSummary
    @State private var deck: Deck?
    @State private var failure: String?
    @State private var page = 0
    @State private var presenting = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    public init(store: DeckStore, summary: DeckSummary) {
        self.store = store
        self.summary = summary
    }

    public var body: some View {
        Group {
            if let deck {
                VStack(spacing: Space.s) {
                    TabView(selection: $page) {
                        ForEach(deck.slides) { slide in
                            SlideCanvas(slide: slide, deckTitle: deck.title,
                                        position: "\(slide.index + 1) / \(deck.slides.count)", store: store)
                                .padding(Space.m)
                                .tag(slide.index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    Text("\(page + 1) / \(deck.slides.count)")
                        .font(Typo.data).foregroundStyle(Palette.muted).padding(.bottom, Space.s)
                    if deck.language != store.language {
                        Text("Not available in \(store.language.displayName): showing \(deck.language.displayName).")
                            .font(Typo.meta).foregroundStyle(Palette.muted)
                    }
                }
            } else if let failure {
                ContentUnavailableView("Deck not available", systemImage: "wifi.slash", description: Text(failure))
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(summary.title.text(in: store.language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { LanguageMenu(store: store) }
            if UIDevice.current.userInterfaceIdiom == .pad, deck != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Present", systemImage: "play.rectangle") { presenting = true }
                }
            }
        }
        .task(id: store.language) { await load() }
        .fullScreenCover(isPresented: $presenting) {
            if let deck { PresenterView(deck: deck, start: page, store: store) { presenting = false } }
        }
    }

    private func load() async {
        failure = nil
        do {
            let loaded = try await store.loadDeck(summary)
            deck = loaded
            page = min(page, max(0, loaded.slides.count - 1))
        } catch is CancellationError {
        } catch {
            if deck == nil { failure = error.localizedDescription }
        }
    }
}
