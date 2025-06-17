import SwiftUI
import PhotosUI
import SwiftData

struct LiveAnalysisView: View {
    @StateObject private var cameraService = CameraService()
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @State private var isLandscape = UIDevice.current.orientation.isLandscape
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            if isLandscape {
                HStack(spacing: 0) {
                    // Main view with camera preview and overlays
                    ZStack(alignment: .top) {
                        CameraPreview(cameraService: cameraService)
                            .ignoresSafeArea()
                        
                        VStack {
                            // Watch Connectivity Status
                            HStack {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(watchConnectivity.connectionStatus == .connected ? Color.green : Color.red)
                                        .frame(width: 8, height: 8)
                                    
                                    Text(watchConnectivity.connectionStatus == .connected ? "Watch Connected" : "Watch Disconnected")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                                
                                if watchConnectivity.connectionStatus != .connected {
                                    Button("Reconnect") {
                                        watchConnectivity.forceReconnect()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(6)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                            
                            // Statistics Panel
                            HStack(spacing: 20) {
                                // Successful Shots
                                VStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 24))
                                    Text("\(cameraService.successfulShots)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                    Text("Successful")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                // Failed Shots
                                VStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 24))
                                    Text("\(cameraService.failedShots)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                    Text("Failed")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .padding(.top, 10)
                            .padding(.horizontal)
                            
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

                        // Button to Reset Stats (previously Reset Stats button, now separated)
                        Button(action: {
                            cameraService.resetStatistics()
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                Text("Reset\nStats")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // Button to Start/Stop the processing
                        Button(action: {
                            cameraService.toggleProcessing()
                        }) {
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(cameraService.isProcessing ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
                                        .frame(width: 90, height: 90)
                                    
                                    Image(systemName: cameraService.isProcessing ? "stop.fill" : "play.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(cameraService.isProcessing ? .red : .white)
                                }
                                
                                Text(cameraService.isProcessing ? "Stop\nAnalysis" : "Start\nAnalysis")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .disabled(!cameraService.isVideoReady)
                        .opacity(cameraService.isVideoReady ? 1.0 : 0.4)
                        .scaleEffect(cameraService.isVideoReady ? 1.0 : 0.95)
                        .animation(.easeInOut(duration: 0.2), value: cameraService.isVideoReady)
                        
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
                            Image(systemName: "iphone.landscape")
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

// Helper to detect device rotation in SwiftUI
extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(DeviceRotationViewModifier(action: action))
    }
}

struct DeviceRotationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void
    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}

#Preview {
    LiveAnalysisView()
        .modelContainer(for: Session.self, inMemory: true)
}
