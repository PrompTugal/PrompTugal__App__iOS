import PTLanes
import SwiftUI
import VisionKit

/// Scans a QR code holding the conductor's `sgi1.` lane link (VisionKit's DataScannerViewController). Calls `onLink`
/// with the first code that parses as a lane; anything else is ignored.
struct LaneScanner: UIViewControllerRepresentable {
    let onLink: (String) -> Void

    @MainActor static var isAvailable: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                                                qualityLevel: .balanced, recognizesMultipleItems: false,
                                                isHighFrameRateTrackingEnabled: false, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onLink: onLink) }

    @MainActor final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onLink: (String) -> Void
        private var done = false
        init(onLink: @escaping (String) -> Void) { self.onLink = onLink }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !done else { return }
            for item in addedItems {
                if case .barcode(let code) = item, let text = code.payloadStringValue, SealedLane.parse(text) != nil {
                    done = true
                    dataScanner.stopScanning()
                    onLink(text)
                    return
                }
            }
        }
    }
}
