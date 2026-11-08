import SwiftUI

/// Root view of the public app. Placeholder: design replaces the body with the real shell
/// and adds its screens under Shell/.
struct PublicShell: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("PrompTugal").font(.largeTitle.bold())
            Text("promptugal.news").foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("public-shell")
    }
}

#Preview {
    PublicShell()
}
