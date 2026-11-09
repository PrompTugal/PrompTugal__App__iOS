import SwiftUI

enum WorkbenchContent {
    static let title = "Workbench"
    static let badge = "Runs on this device"
    static let defaultPrompt = "In three sentences, explain what an Agent Behaviour Policy is and why it matters for AI agents."
}

@MainActor
@Observable
final class WorkbenchModel {
    var prompt = WorkbenchContent.defaultPrompt
    var answer = ""
    var metrics: RunMetrics?
    var error: String?
    var isRunning = false
    let status: ModelStatus

    init(status: ModelStatus = OnDeviceModel.status) {
        self.status = status
    }

    var canRun: Bool {
        status.isAvailable && !isRunning && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func run() async {
        guard canRun else { return }
        isRunning = true
        answer = ""
        metrics = nil
        error = nil
        defer { isRunning = false }
        do {
            metrics = try await OnDeviceModel.run(prompt: prompt) { [weak self] text in
                self?.answer = text
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct WorkbenchView: View {
    @State private var model = WorkbenchModel()

    var body: some View {
        Form {
            Section {
                HStack {
                    Label(OnDeviceModel.name, systemImage: "cpu")
                        .font(.headline)
                    Spacer()
                    if model.status.isAvailable {
                        DeviceBadge()
                    }
                }
                if case .unavailable(let reason) = model.status {
                    Text(reason)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Prompt") {
                TextField("Prompt", text: $model.prompt, axis: .vertical)
                    .lineLimit(3...8)
                    .disabled(model.isRunning)
                Button {
                    Task { await model.run() }
                } label: {
                    HStack {
                        Text(model.isRunning ? "Running…" : "Run")
                        if model.isRunning {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(!model.canRun)
            }

            if let metrics = model.metrics {
                Section("Metrics") {
                    MetricRow(name: "Time to first token", value: metrics.timeToFirstToken.map { Self.seconds($0) } ?? "–")
                    MetricRow(name: metrics.tokensAreEstimated ? "Tokens per second (≈)" : "Tokens per second",
                              value: metrics.tokensPerSecond.map { String(format: "%.1f", $0) } ?? "–")
                    MetricRow(name: metrics.tokensAreEstimated ? "Tokens (≈)" : "Tokens", value: "\(metrics.tokens)")
                    MetricRow(name: "Total", value: Self.seconds(metrics.total))
                }
            }

            if !model.answer.isEmpty {
                Section("Answer") {
                    Text(model.answer)
                        .textSelection(.enabled)
                }
            }

            if let error = model.error {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(WorkbenchContent.title)
    }

    static func seconds(_ t: TimeInterval) -> String {
        String(format: "%.2f s", t)
    }
}

private struct MetricRow: View {
    let name: String
    let value: String

    var body: some View {
        LabeledContent(name) {
            Text(value).monospacedDigit()
        }
    }
}

private struct DeviceBadge: View {
    var body: some View {
        Label(WorkbenchContent.badge, systemImage: "lock.iphone")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.green.opacity(0.15), in: Capsule())
            .foregroundStyle(.green)
            .accessibilityLabel("\(WorkbenchContent.badge): no data leaves the device")
    }
}

#Preview {
    NavigationStack { WorkbenchView() }
}
