import PhotosUI
import SwiftData
import SwiftUI

struct LiveAnalysisView: View {
    @StateObject private var cameraService = CameraViewModel()
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @State private var isLandscape = UIDevice.current.orientation.isLandscape
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            if isLandscape {
                HStack(spacing: 0) {
                    // Main view with camera preview and overlays
                    ZStack(alignment: .top) {
                        CameraView(cameraService: cameraService)
                            .ignoresSafeArea()
                        
                        // Top bar with Statistics (right)
                        VStack {
                            HStack {
                                
                                Spacer()
                                // Statistics Panel (top right)
                                HStack(spacing: 16) {
                                    // Successful Shots
                                    VStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 18))
                                        Text("\(cameraService.successfulShots)")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.green)
                                    }
                                    
                                    // Failed Shots
                                    VStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 18))
                                        Text("\(cameraService.failedShots)")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            
                            Spacer()
                        }
                        
                        // Racquet Angle Result at the bottom
                        VStack {
                            Spacer()
                            
                            if !cameraService.angleClassification.isEmpty {
                                HStack {
                                    Image(systemName: "scope")
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Racquet Face Angle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(cameraService.angleClassification)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.thinMaterial)
                                .cornerRadius(10)
                                .shadow(radius: 1)
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .animation(.easeInOut(duration: 0.3), value: cameraService.angleClassification)
                            }
                        }
                    }
                    
                    // Vertical Separator
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 1)
                    
                    // Right-side control panel
                    VStack(spacing: 30) {
                        
                        Spacer()
                        
                        Spacer()
                        
                        // Button to Start/Stop the processing
                        Button(action: {
                            cameraService.toggleProcessing()
                        }) {
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 90, height: 90)
                                    
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: cameraService.isProcessing ? "stop.fill" : "circle.fill")
                                        .font(.system(size: cameraService.isProcessing ? 40 : 70))
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .disabled(!cameraService.isVideoReady)
                        .opacity(cameraService.isVideoReady ? 1.0 : 0.4)
                        .scaleEffect(cameraService.isVideoReady ? 1.0 : 0.95)
                        .animation(.easeInOut(duration: 0.2), value: cameraService.isVideoReady)
                        
                        // Button to Reset Stats (previously Reset Stats button, now separated)
                        Button(action: {
                            cameraService.resetStatistics()
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                Text("Reset\nStats")
                                    .font(.system(size:8))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)
                            .cornerRadius(12)
                        }
                        
                        Spacer()
                        
                    }
                    .frame(width: 120)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.6), Color.black.opacity(0.3)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
                .ignoresSafeArea()
                .background(Color.black)
                .orientationLock(.landscape)
                .onAppear {
                    cameraService.setContext(modelContext)
                }
            } else {
                Color.black.ignoresSafeArea()
                    .overlay(
                        VStack {
                            Image(systemName: "iphone.gen3.landscape")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            Text("Please rotate your device to landscape")
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding()
                        }
                    )
                    .orientationLock(.landscape)
            }
        }
        .onAppear {
            isLandscape = UIDevice.current.orientation.isLandscape
        }
        .onRotate { newOrientation in
            isLandscape = newOrientation.isLandscape
        }
    }
}

//#Preview {
//    LiveAnalysisView()
//        .modelContainer(for: Session.self, inMemory: true)
//}
