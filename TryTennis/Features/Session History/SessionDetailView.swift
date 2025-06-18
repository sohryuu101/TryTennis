import SwiftUI
import SwiftData
import AVKit
import Photos

struct SessionDetailView: View {
    @ObservedObject var viewModel: SessionDetailViewModel
    @State private var selectedAngle: SessionDetailViewModel.AngleType = .best
    @State private var showingVideoPlayer = false
    @State private var clipStartTime: Double = 0.0
    @State private var showingArticleSheet = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Date and time row
                    HStack {
                        Text(viewModel.formattedDate)
                            .font(.subheadline)
                            .foregroundColor(Color(white: 0.7))
                        Spacer()
                        Text(viewModel.formattedTime)
                            .font(.subheadline)
                            .foregroundColor(Color(white: 0.7))
                    }
                    .padding(.top, 8)
                    .padding(.horizontal)

                    // Title
                    Text("Highlights")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(red: 220/255, green: 243/255, blue: 220/255))
                        .padding(.horizontal)
                        .padding(.top, 2)

                    // Segmented control
                    HStack(spacing: 0) {
                        ForEach(SessionDetailViewModel.AngleType.allCases) { angle in
                            Button(action: { 
                                selectedAngle = angle
                                viewModel.loadVideoThumbnail(for: angle)
                            }) {
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
                        
                        if let thumbnail = viewModel.videoThumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(18)
                                .allowsHitTesting(false)
                        }
                        
                        if viewModel.isLoadingVideo {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                                .allowsHitTesting(false)
                        }
                        
                        if !viewModel.isLoadingVideo && viewModel.angleTimestamp(for: selectedAngle) == nil {
                            VStack {
                                Image(systemName: "video.slash")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color(white: 0.5))
                                Text("No \(selectedAngle.rawValue.lowercased()) shot recorded")
                                    .font(.caption)
                                    .foregroundColor(Color(white: 0.5))
                                    .multilineTextAlignment(.center)
                            }
                            .allowsHitTesting(false)
                        }
                        
                        // Only show play button if there's a video for the selected angle
                        if viewModel.angleTimestamp(for: selectedAngle) != nil {
                            Button(action: {
                                viewModel.preparePlayer(for: selectedAngle) { player in
                                    if let player = player {
                                        viewModel.player = player
                                        showingVideoPlayer = true
                                    }
                                }
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .resizable()
                                    .frame(width: 56, height: 56)
                                    .foregroundColor(Color(white: 0.8))
                            }
                            .disabled(viewModel.isLoadingVideo)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .onAppear {
                        viewModel.loadVideoThumbnail(for: selectedAngle)
                    }

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
                        VStack(alignment: .leading, spacing: 0) {
                            Image("LiveAnalysis")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 140)
                                .clipped()
                                .cornerRadius(20)
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
                    .onTapGesture {
                        showingArticleSheet = true
                    }
                    .sheet(isPresented: $showingArticleSheet) {
                        RacquetHeadArticleSheet()
                    }
                }
            }
            .navigationTitle("Session Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showingVideoPlayer) {
                if let player = viewModel.player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .onDisappear {
                            player.pause()
                            viewModel.player = nil // Release player
                            viewModel.isLoadingVideo = false
                        }
                }
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
