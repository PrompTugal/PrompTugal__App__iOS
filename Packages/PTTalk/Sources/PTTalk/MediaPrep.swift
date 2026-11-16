import AVFoundation
import CoreTransferable
import Foundation
import UIKit
import UniformTypeIdentifiers

/// Pictures and videos made small enough for a lane before they are sealed.
public enum MediaPrep {
    /// A JPEG no wider or taller than `longestSide` pixels (from VoiceDebrief `PictureSender.jpeg`, Apache 2.0).
    public static func jpeg(_ image: UIImage, longestSide: CGFloat = 2048, quality: CGFloat = 0.75) -> Data? {
        let size = image.size
        let scale = min(1, longestSide / max(size.width, size.height, 1))
        let target = CGSize(width: max(1, (size.width * scale).rounded()), height: max(1, (size.height * scale).rounded()))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let drawn = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return drawn.jpegData(compressionQuality: quality)
    }

    /// The video as an MP4 at medium quality (smaller, and a format any receiver opens). Falls back to the original
    /// file when the export fails.
    public static func compressedVideo(_ url: URL) async -> URL {
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("video-\(UUID().uuidString.prefix(8)).mp4")
        guard let session = AVAssetExportSession(asset: AVURLAsset(url: url), presetName: AVAssetExportPresetMediumQuality) else { return url }
        do {
            try await session.export(to: out, as: .mp4)
            return out
        } catch {
            return url
        }
    }

    public static func size(_ url: URL) -> Int {
        ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?.intValue ?? 0
    }
}

/// A video chosen in Photos, copied to a temporary file.
public struct PickedMovie: Transferable, Sendable {
    public let url: URL

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("picked-\(UUID().uuidString.prefix(8)).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}
