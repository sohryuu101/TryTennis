import SwiftUI
import SwiftData
import AVKit
import Photos

struct SessionDetailView: View {
    @Environment(SessionDetailViewModel.self) private var viewModel: SessionDetailViewModel
    @State private var showingVideoPlayer = false
    @State private var player: AVPlayer? // Player for the full video
    @State private var clipStartTime: Double = 0.0
    private let clipDuration: Double = 2.0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 5 / 255, green: 19 / 255, blue: 3 / 255),
                         Color(red: 8 / 255, green: 34 / 255, blue: 5 / 255)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(viewModel.session.timestamp, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.white)
                            Text("Total Attempts: ")
                                .foregroundColor(.white.opacity(0.8))
                            Text("\(viewModel.session.totalAttempts)")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Successful Shots: ")
                                .foregroundColor(.white.opacity(0.8))
                            Text("\(viewModel.session.successfulShots)")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Failed Shots: ")
                                .foregroundColor(.white.opacity(0.8))
                            Text("\(viewModel.session.failedShots)")
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(15)
                    
                    // Video Clips Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Racquet Angle Clips")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if let optimalTimestamp = viewModel.session.optimalRacquetTimestamp {
                            ClipButton(title: "Optimal Angle", color: .green) {
                                clipStartTime = optimalTimestamp
                                prepareAndShowVideoPlayer()
                            }
                        }
                        
                        if let openTimestamp = viewModel.session.openRacquetTimestamp {
                            ClipButton(title: "Open Angle", color: .orange) {
                                clipStartTime = openTimestamp
                                prepareAndShowVideoPlayer()
                            }
                        }
                        
                        if let closedTimestamp = viewModel.session.closedRacquetTimestamp {
                            ClipButton(title: "Closed Angle", color: .red) {
                                clipStartTime = closedTimestamp
                                prepareAndShowVideoPlayer()
                            }
                        }
                        
                        if viewModel.session.optimalRacquetTimestamp == nil &&
                           viewModel.session.openRacquetTimestamp == nil &&
                           viewModel.session.closedRacquetTimestamp == nil {
                            Text("No clips available for this session")
                                .foregroundColor(.white.opacity(0.6))
                                .italic()
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(15)
                }
                .padding()
            }
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 50 / 255.0, green: 95 / 255.0, blue: 44 / 255.0), for: .navigationBar)
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
    return SessionDetailView()
        .environment(SessionDetailViewModel(session: exampleSession))
        .modelContainer(for: Session.self, inMemory: true)
} 
