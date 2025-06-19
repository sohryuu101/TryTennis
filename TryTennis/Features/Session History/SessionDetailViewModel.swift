import Foundation
import SwiftUI
import AVKit
import Photos

class SessionDetailViewModel: ObservableObject {
    let session: Session
    @Published var videoThumbnail: UIImage? = nil
    @Published var isLoadingVideo = false
    @Published var player: AVPlayer? = nil
    let clipDuration: Double = 2.0
    private var boundaryObserver: Any?
    private var tempClipURL: URL?

    init(session: Session) {
        self.session = session
    }

    enum AngleType: String, CaseIterable, Identifiable {
        case best = "Best Angle"
        case opened = "Too Opened"
        case closed = "Too Closed"
        var id: String { rawValue }
    }

    func angleTimestamp(for angle: AngleType) -> Double? {
        switch angle {
        case .best:
            return session.optimalRacquetTimestamp
        case .opened:
            return session.openRacquetTimestamp
        case .closed:
            return session.closedRacquetTimestamp
        }
    }

    func loadVideoThumbnail(for angle: AngleType) {
        guard let _ = angleTimestamp(for: angle) else {
            self.videoThumbnail = nil
            return
        }
        guard let localIdentifier = session.videoLocalIdentifier else {
            self.videoThumbnail = nil
            return
        }
        isLoadingVideo = true
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let phAsset = fetchResult.firstObject else {
            isLoadingVideo = false
            self.videoThumbnail = nil
            return
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        PHImageManager.default().requestImage(for: phAsset, targetSize: CGSize(width: 400, height: 400), contentMode: .aspectFill, options: options) { image, _ in
            DispatchQueue.main.async {
                self.videoThumbnail = image
                self.isLoadingVideo = false
            }
        }
    }

    // Export a 2-second trimmed clip (1s before, 1s after impact) to a temp file
    func exportTrimmedClip(for angle: AngleType, completion: @escaping (URL?) -> Void) {
        guard let localIdentifier = session.videoLocalIdentifier, let impactTime = angleTimestamp(for: angle) else {
            completion(nil)
            return
        }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let phAsset = fetchResult.firstObject else {
            completion(nil)
            return
        }
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { avAsset, _, _ in
            guard let avAsset = avAsset else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let clipStart = max(0, impactTime - 1.0)
            let clipEnd = impactTime + 1.0
            let timeRange = CMTimeRange(start: CMTime(seconds: clipStart, preferredTimescale: 600), duration: CMTime(seconds: clipEnd - clipStart, preferredTimescale: 600))
            let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
            exportSession?.outputURL = tempURL
            exportSession?.outputFileType = .mp4
            exportSession?.timeRange = timeRange
            exportSession?.exportAsynchronously {
                DispatchQueue.main.async {
                    if exportSession?.status == .completed {
                        self.tempClipURL = tempURL
                        completion(tempURL)
                    } else {
                        completion(nil)
                    }
                }
            }
        }
    }

    func preparePlayer(for angle: AngleType, completion: @escaping (AVPlayer?) -> Void) {
        // Clean up any previous observer and temp file
        if let observer = boundaryObserver, let player = player {
            player.removeTimeObserver(observer)
            boundaryObserver = nil
        }
        if let tempClipURL = tempClipURL {
            try? FileManager.default.removeItem(at: tempClipURL)
            self.tempClipURL = nil
        }
        isLoadingVideo = true
        exportTrimmedClip(for: angle) { [weak self] url in
            guard let self = self else { completion(nil); return }
            self.isLoadingVideo = false
            guard let url = url else {
                completion(nil)
                return
            }
            let playerItem = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: playerItem)
            self.player = player
            completion(player)
        }
    }

    // Date formatting helpers
    var formattedDate: String {
        session.timestamp.formatted(.dateTime.month(.wide).day().year())
    }
    var formattedTime: String {
        session.timestamp.formatted(.dateTime.hour().minute())
    }
} 