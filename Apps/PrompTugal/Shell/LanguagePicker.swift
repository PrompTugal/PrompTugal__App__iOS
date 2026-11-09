import PTCore
import SwiftUI

/// The language button: a globe and the current culture's code ("🌐 EN"), at the top of every main screen. When another
/// culture is active, a small "EN" beside it goes straight back to English. The choice is kept on this device only.
struct LanguageButton: View {
    @AppStorage(AppCulture.storageKey) private var cultureID = AppCulture.english
    @State private var choosing = false

    var body: some View {
        HStack(spacing: Space.xs) {
            Button { choosing = true } label: {
                Label {
                    Text(verbatim: AppCulture.culture(cultureID).code)
                } icon: {
                    Image(systemName: "globe")
                }
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
            }
            .accessibilityLabel(Text("Language"))
            .accessibilityValue(Text(verbatim: AppCulture.culture(cultureID).name))
            .accessibilityIdentifier("pt.language")
            if cultureID != AppCulture.english {
                Button { AppCulture.select(AppCulture.english); cultureID = AppCulture.english } label: {
                    Text(verbatim: "EN").font(.caption.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Palette.paper2))
                }
                .accessibilityLabel(Text(verbatim: "English"))
                .accessibilityIdentifier("pt.language.en")
            }
        }
        .sheet(isPresented: $choosing) {
            LanguageList(selection: cultureID) { id in
                AppCulture.select(id)
                cultureID = id
                choosing = false
            } close: { choosing = false }
        }
    }
}

/// All the cultures, each in its own language, the current one ticked. English is the first row.
private struct LanguageList: View {
    let selection: String
    let choose: (String) -> Void
    let close: () -> Void

    var body: some View {
        NavigationStack {
            List(AppCulture.all) { culture in
                Button { choose(culture.id) } label: {
                    HStack {
                        Text(verbatim: culture.name).foregroundStyle(Palette.ink)
                        Spacer()
                        if culture.id == selection {
                            Image(systemName: "checkmark").foregroundStyle(Palette.red).accessibilityHidden(true)
                        }
                    }
                }
                // Each row is read in its own language, whatever the app's language is.
                .environment(\.locale, culture.locale)
                .accessibilityAddTraits(culture.id == selection ? .isSelected : [])
                .accessibilityIdentifier("pt.language.\(culture.id)")
            }
            .navigationTitle(Text("Language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: close) }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview("Language button") {
    NavigationStack { Color.clear.toolbar { ToolbarItem(placement: .topBarLeading) { LanguageButton() } } }
}
