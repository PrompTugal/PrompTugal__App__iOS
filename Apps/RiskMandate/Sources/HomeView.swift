import SwiftUI

enum RiskMandateContent {
    static let title = "RiskMandate"
    static let line = "Agent Behaviour Policies, demos and explanations. Coming after Web Summit."
    static let abpURL = URL(string: "https://riskmandate.ai/abp.html")!
}

struct HomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text(RiskMandateContent.title)
                .font(.largeTitle.bold())
            Text(RiskMandateContent.line)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Link("Read about Agent Behaviour Policies", destination: RiskMandateContent.abpURL)
                .font(.headline)
        }
        .padding(24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    HomeView()
}
