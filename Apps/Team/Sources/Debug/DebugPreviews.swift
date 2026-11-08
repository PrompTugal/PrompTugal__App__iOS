import SGitVault
import SwiftUI

// Previews for the debug panels and settings, at iPhone and iPad sizes.

#Preview("Debug · iPhone") {
    NavigationStack { DebugHomeView() }.environment(PreviewSamples.previewData()).environment(VaultTrafficLog()).phonePreview()
}

#Preview("Debug · iPad") {
    NavigationStack { DebugHomeView() }.environment(PreviewSamples.previewData()).environment(VaultTrafficLog()).padPreview()
}

#Preview("Network · iPhone") {
    NavigationStack { NetworkPanel() }.phonePreview()
}

#Preview("Vault pipeline · iPhone") {
    NavigationStack {
        DecryptPipelineView(path: "bare/data/obj-cas-imm-0000sample",
                            events: VaultTrafficSamples.events.filter { $0.path == "bare/data/obj-cas-imm-0000sample" }.reversed())
    }
    .phonePreview()
}

#Preview("Vault traffic · iPad") {
    NavigationStack { VaultTrafficPanel(sample: VaultTrafficSamples.events) }.padPreview()
}

#Preview("Build · iPhone") {
    NavigationStack { BuildPanel() }.environment(PreviewSamples.previewData()).phonePreview()
}

#Preview("Settings · iPhone") {
    NavigationStack { SettingsView() }.environment(PreviewSamples.previewData()).phonePreview()
}
