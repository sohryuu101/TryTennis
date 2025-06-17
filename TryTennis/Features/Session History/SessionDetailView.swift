import SwiftUI
import SwiftData
import AVKit
import Photos

struct SessionDetailView: View {
    let viewModel: SessionDetailViewModel
    @State private var selectedAngle: AngleType = .best
    @State private var showingVideoPlayer = false
    @State private var player: AVPlayer? // Player for the full video
    @State private var clipStartTime: Double = 0.0
    private let clipDuration: Double = 2.0
    
    enum AngleType: String, CaseIterable, Identifiable {
        case best = "Best Angle"
        case opened = "Too Opened"
        case closed = "Too Closed"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Date and time row
                    HStack {
                        Text(viewModel.session.timestamp.formatted(.dateTime.month(.wide).day().year()))
                            .font(.subheadline)
                            .foregroundColor(Color(white: 0.7))
                        Spacer()
                        Text(viewModel.session.timestamp.formatted(.dateTime.hour().minute()))
                            .font(.subheadline)
                            .foregroundColor(Color(white: 0.7))
                    }
                    .padding(.top, 8)
                    .padding(.horizontal)

                    // Title
                    Text("Your Racquet Head Angle")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(red: 220/255, green: 243/255, blue: 220/255))
                        .padding(.horizontal)
                        .padding(.top, 2)

                    // Segmented control
                    HStack(spacing: 0) {
                        ForEach(AngleType.allCases) { angle in
                            Button(action: { selectedAngle = angle }) {
                                Text(angle.rawValue)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(selectedAngle == angle ? .black : .white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(selectedAngle == angle ? Color.white : Color.clear)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .background(
                        Capsule().fill(Color.white.opacity(0.08))
                    )
                    .padding(.horizontal)
                    .padding(.top, 12)

                    // Video preview
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(white: 0.12))
                            .frame(height: 200)
                        Button(action: {
                            // Play the video for the selected angle if available
                            if let ts = angleTimestamp(for: selectedAngle) {
                                clipStartTime = ts
                                prepareAndShowVideoPlayer()
                            }
                        }) {
                            Image(systemName: "play.circle.fill")
                                .resizable()
                                .frame(width: 56, height: 56)
                                .foregroundColor(Color(white: 0.8))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)

                    // Stats row
                    HStack(spacing: 0) {
                        VStack {
                            Text("\(viewModel.session.successfulShots)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color.orange)
                            Text("SUCCESS")
                                .font(.caption)
                                .foregroundColor(Color.orange)
                        }
                        .frame(maxWidth: .infinity)
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(white: 0.12))
                                .frame(height: 56)
                            VStack {
                                Text("\(viewModel.session.totalAttempts)")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Text("TOTAL ATTEMPTS")
                                    .font(.caption)
                                    .foregroundColor(Color.orange)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        VStack {
                            Text("\(viewModel.session.failedShots)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color.orange)
                            Text("FAIL")
                                .font(.caption)
                                .foregroundColor(Color.orange)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    .padding(.top, 18)

                    // About section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("About Racquet Head Angle")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(red: 220/255, green: 243/255, blue: 220/255))
                            .padding(.top, 24)
                            .padding(.horizontal)
                        Image("racquet_angle_info")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 140)
                            .clipped()
                            .cornerRadius(20)
                            .padding(.horizontal)
                            .padding(.top, 12)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Learn About Racquet Head Angle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(red: 220/255, green: 243/255, blue: 220/255))
                            Text("How the angle of your racquet face impacts your shots and how to improve yours.")
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 18)
                    }
                    .background(Color(white: 0.12))
                    .cornerRadius(24)
                    .padding(.horizontal)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Session Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showingVideoPlayer) {
                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .onDisappear {
                            player.pause()
                            self.player = nil // Release player
                        }
                }
            }
        }
    }

    private func angleTimestamp(for angle: AngleType) -> Double? {
        switch angle {
        case .best:
            return viewModel.session.optimalRacquetTimestamp
        case .opened:
            return viewModel.session.openRacquetTimestamp
        case .closed:
            return viewModel.session.closedRacquetTimestamp
        }
    }
    
    private func prepareAndShowVideoPlayer() {
        guard let localIdentifier = viewModel.session.videoLocalIdentifier else {
            print("DEBUG: Video local identifier not found.")
            return
        }
        
        print("DEBUG: Attempting to fetch PHAsset with localIdentifier: \(localIdentifier)")
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let phAsset = fetchResult.firstObject else {
            print("DEBUG: PHAsset not found for identifier: \(localIdentifier)")
            return
        }
        
        print("DEBUG: PHAsset found. Requesting AVPlayerItem...")
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        
        PHImageManager.default().requestPlayerItem(forVideo: phAsset, options: options) { playerItem, info in
            guard let playerItem = playerItem else {
                print("DEBUG: Failed to get AVPlayerItem for video. Info: \(info ?? [:])")
                return
            }
            DispatchQueue.main.async {
                self.player = AVPlayer(playerItem: playerItem)
                let seekTime = CMTime(seconds: self.clipStartTime, preferredTimescale: 600)
                print("DEBUG: AVPlayerItem obtained. Seeking to: \(self.clipStartTime) seconds.")
                self.player?.seek(to: seekTime) {
                    completed in
                    if completed {
                        print("DEBUG: Seek completed. Starting playback.")
                        self.player?.play()
                        // Stop playing after clipDuration
                        let endTime = CMTime(seconds: self.clipStartTime + self.clipDuration, preferredTimescale: 600)
                        print("DEBUG: Setting end time to: \(self.clipStartTime + self.clipDuration) seconds.")
                        self.player?.seek(to: endTime, toleranceBefore: .zero, toleranceAfter: .zero) {
                            completed in
                            if completed {
                                print("DEBUG: End seek completed. Pausing player.")
                                self.player?.pause()
                            }
                        }
                    } else {
                        print("DEBUG: Seek failed.")
                    }
                }
                self.showingVideoPlayer = true
                print("DEBUG: Showing video player.")
            }
        }
    }
}

struct ClipButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(color)
                Text(title)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

#Preview {
    let exampleSession = Session(timestamp: Date(), totalAttempts: 10, successfulShots: 7, failedShots: 3)
    return SessionDetailView(viewModel: SessionDetailViewModel(session: exampleSession))
        .modelContainer(for: Session.self, inMemory: true)
} 
