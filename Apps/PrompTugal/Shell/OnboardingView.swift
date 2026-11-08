import PTCore
import SwiftUI

/// ONB-1: one screen, shown once on the first launch, and again from Settings ("How PrompTugal works"). It asks for
/// nothing: no notification prompt, no account. "Choose talks" opens Explore on Talks; "Not now" closes it on Now.
struct OnboardingView: View {
    /// `chooseTalks` is true when the person tapped "Choose talks".
    let finish: (_ chooseTalks: Bool) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Kicker("Lisbon · 9–12 Nov")
                    Text("Your summit, on your phone").font(Typo.display).foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                VStack(alignment: .leading, spacing: Space.l) {
                    row("star", "Pick your talks",
                        "Tap the star on any talk, in Explore or on Now. It goes into My program.")
                    row("calendar.badge.exclamationmark", "See clashes and free time",
                        "My program puts your talks in order, marks the ones that clash and shows the gaps between them. A reminder comes before each one.")
                    row("wifi.slash", "Works offline",
                        "The agenda and the news are saved here and work with no signal. Your picks never leave your phone.")
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.l)
            .frame(maxWidth: Space.readable, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.paper.ignoresSafeArea())
        // At the largest text sizes the screen scrolls and the buttons stay in view.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Space.s) {
                Button { finish(true) } label: {
                    Text("Choose talks").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("pt.onboarding.choose")
                Button { finish(false) } label: {
                    Text("Not now").frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.muted)
                .accessibilityIdentifier("pt.onboarding.skip")
            }
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.m)
            .frame(maxWidth: Space.readable)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
        .accessibilityIdentifier("pt.onboarding")
    }

    private func row(_ symbol: String, _ headline: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: symbol)
                .font(.title3).foregroundStyle(Palette.red)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Palette.paper2))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline).font(Typo.headline).foregroundStyle(Palette.ink)
                Text(body).font(Typo.body).foregroundStyle(Palette.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Onboarding") {
    OnboardingView { _ in }.phonePreview()
}
