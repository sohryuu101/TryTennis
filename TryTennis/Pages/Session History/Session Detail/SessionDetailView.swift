import AVKit
import Photos
import SwiftData
import SwiftUI

struct SessionDetailView: View {
    @ObservedObject var viewModel: SessionDetailViewModel
    @State private var selectedAngle: SessionDetailViewModel.AngleType = .best
    @State private var showingVideoPlayer = false
    @State private var clipStartTime: Double = 0.0
    @State private var showingArticleSheet = false
    
    var body: some View {
        ZStack {
            Token.black.swiftUIColor.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Date and time row
                    HStack {
                        Text(viewModel.formattedDate)
                            .font(.subheadline)
                            .foregroundColor(Token.gray300.swiftUIColor)
                        Spacer()
                        Text(viewModel.formattedTime)
                            .font(.subheadline)
                            .foregroundColor(Token.gray300.swiftUIColor)
                    }
                    .padding(.top, 8)
                    .padding(.horizontal)

                    // Title
                    Text("Highlights")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Token.primary100.swiftUIColor)
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
                                    .foregroundColor(selectedAngle == angle ? Token.black.swiftUIColor : Token.white.swiftUIColor)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(selectedAngle == angle ? Token.white.swiftUIColor : Color.clear)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .background(
                        Capsule().fill(Token.white.swiftUIColor.opacity(0.08))
                    )
                    .padding(.horizontal)
                    .padding(.top, 12)

                    // Video preview
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Token.gray900.swiftUIColor)
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
                                TryTennisIcon.videoSlash.swiftUIImage
                                    .font(.system(size: 32))
                                    .foregroundColor(Token.gray500.swiftUIColor)
                                Text("No \(selectedAngle.rawValue.lowercased()) shot recorded")
                                    .font(.caption)
                                    .foregroundColor(Token.gray500.swiftUIColor)
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
                                TryTennisIcon.playCircleFill.swiftUIImage
                                    .resizable()
                                    .frame(width: 56, height: 56)
                                    .foregroundColor(Token.gray300.swiftUIColor)
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
                                .foregroundColor(Token.accent500.swiftUIColor)
                            Text("SUCCESS")
                                .font(.caption)
                                .foregroundColor(Token.accent500.swiftUIColor)
                        }
                        .frame(maxWidth: .infinity)
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Token.gray900.swiftUIColor)
                                .frame(height: 56)
                            VStack {
                                Text("\(viewModel.session.totalAttempts)")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Token.white.swiftUIColor)
                                Text("TOTAL ATTEMPTS")
                                    .font(.caption)
                                    .foregroundColor(Token.accent500.swiftUIColor)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        VStack {
                            Text("\(viewModel.session.failedShots)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Token.accent500.swiftUIColor)
                            Text("FAIL")
                                .font(.caption)
                                .foregroundColor(Token.accent500.swiftUIColor)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    .padding(.top, 18)

                    // About section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("About Racquet Head Angle")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Token.primary100.swiftUIColor)
                            .padding(.top, 24)
                            .padding(.horizontal)
                        VStack(alignment: .leading, spacing: 0) {
                            TryTennisIcon.liveAnalysis.swiftUIImage
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 140)
                                .clipped()
                                .cornerRadius(20)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Learn About Racquet Head Angle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Token.primary100.swiftUIColor)
                                Text("How the angle of your racquet face impacts your shots and how to improve yours.")
                                    .font(.system(size: 15))
                                    .foregroundColor(Token.white.swiftUIColor)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 18)
                        }
                        .background(Token.gray900.swiftUIColor)
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
            .toolbarBackground(Token.black.swiftUIColor, for: .navigationBar)
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
                TryTennisIcon.playCircleFill.swiftUIImage
                    .foregroundColor(color)
                Text(title)
                    .foregroundColor(Token.white.swiftUIColor)
                Spacer()
                TryTennisIcon.chevronRight.swiftUIImage
                    .foregroundColor(Token.white.swiftUIColor.opacity(0.6))
            }
            .padding()
            .background(Token.white.swiftUIColor.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

#Preview {
    let exampleSession = Session(timestamp: Date(), totalAttempts: 10, successfulShots: 7, failedShots: 3)
    return SessionDetailView(viewModel: SessionDetailViewModel(session: exampleSession))
        .modelContainer(for: Session.self, inMemory: true)
} 
