import PhotosUI
import SwiftUI

struct LiveAnalysisView: View {
    @StateObject private var cameraService = CameraService()
    @State private var isLandscape = UIDevice.current.orientation.isLandscape
    
    var body: some View {
        ZStack {
            if isLandscape {
                HStack(spacing: 0) {
                    // Main view with camera preview and overlays
                    ZStack(alignment: .top) {
                        CameraPreview(cameraService: cameraService)
                            .ignoresSafeArea()
                        
                        VStack {
                            // Classification Results
                            VStack(spacing: 12) {
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
                                
                                // Swing Detection Status
                                HStack {
                                    Image(systemName: cameraService.strokeClassification.contains("Impact") ? "target" : "waveform.path.ecg")
                                        .foregroundColor(cameraService.strokeClassification.contains("Impact") ? .green : .blue)
                                    Text(cameraService.strokeClassification)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .shadow(radius: 2)
                                
                                // Racquet Angle Result
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
                                }
                            }
                            .padding(.top, 20)
                            .padding(.horizontal)
                            
                            Spacer()
                            
                            // Debug info at the bottom
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.cyan)
                                        .font(.caption)
                                    Text("System Status")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                }
                                
                                HStack {
                                    Circle()
                                        .fill(cameraService.isProcessing ? .green : .gray)
                                        .frame(width: 8, height: 8)
                                    Text("Processing: \(cameraService.isProcessing ? "ACTIVE" : "IDLE")")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                }
                                
                                HStack {
                                    Circle()
                                        .fill(cameraService.isVideoReady ? .green : .red)
                                        .frame(width: 8, height: 8)
                                    Text("Camera: \(cameraService.isVideoReady ? "READY" : "NOT_READY")")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                }
                                
                                if cameraService.isProcessing {
                                    HStack {
                                        Image(systemName: "brain.head.profile")
                                            .foregroundColor(.green)
                                            .font(.caption2)
                                        Text("AI analyzing movement patterns...")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(10)
                            .padding(.bottom, 20)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Vertical Separator
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 1)
                    
                    // Right-side control panel
                    VStack(spacing: 30) {
                        Spacer()
                        
                        // Button to select a video (now reset stats)
                        Button(action: {
                            cameraService.resetStatistics()
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise") // Changed icon for reset
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                Text("Reset\nStats") // Changed text for reset
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
                        
                        // Model Status Indicator
                        // VStack(spacing: 12) {
                        //     Text("AI Models")
                        //         .font(.caption2)
                        //         .fontWeight(.semibold)
                        //         .foregroundColor(.white.opacity(0.8))
                            
                        //     VStack(spacing: 8) {
                        //         HStack(spacing: 6) {
                        //             Circle()
                        //                 .fill(Color.green)
                        //                 .frame(width: 6, height: 6)
                        //             Text("Swing Detector")
                        //                 .font(.caption2)
                        //                 .foregroundColor(.white)
                        //         }
                                
                        //         HStack(spacing: 6) {
                        //             Circle()
                        //                 .fill(Color.green)
                        //                 .frame(width: 6, height: 6)
                        //             Text("Angle Classifier")
                        //                 .font(.caption2)
                        //                 .foregroundColor(.white)
                        //         }
                        //     }
                        // }
                        // .padding(.bottom, 20)
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
}
