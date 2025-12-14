import SwiftUI

struct RacquetHeadArticleSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("Racquet Head Angle")
                            .font(.title2).bold()
                            .foregroundColor(Token.primary100.swiftUIColor)
                        Text("The racquet head angle is the tilt of your racquet head when making **contact** with the ball. This angle affects where the ball goes and how it behaves.")
                            .foregroundColor(Token.white.swiftUIColor)
                            .font(.body)
                    }
                    Divider().background(Token.white.swiftUIColor.opacity(0.2))
                    Group {
                        Text("Watch This Example")
                            .font(.title3).bold()
                            .foregroundColor(Token.primary100.swiftUIColor)
                        Text("See the correct racquet head angle from a side angle.")
                            .foregroundColor(Token.white.swiftUIColor)
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Token.white.swiftUIColor.opacity(0.08))
                                .frame(height: 180)
                            TryTennisIcon.playCircleFill.swiftUIImage
                                .resizable()
                                .frame(width: 48, height: 48)
                                .foregroundColor(Token.gray300.swiftUIColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Proper Forehand Contact — Racquet Face Angle")
                                .font(.headline)
                                .foregroundColor(Token.white.swiftUIColor)
                            HStack(spacing: 12) {
                                Label {
                                    Text("Duration: 1:20")
                                } icon: {
                                    TryTennisIcon.clock.swiftUIImage
                                }
                                .foregroundColor(Token.white.swiftUIColor.opacity(0.8))
                                
                                Label {
                                    Text("Filmed from the same angle used in TryTennis Live Analysis")
                                } icon: {
                                    TryTennisIcon.mapPinEllipse.swiftUIImage
                                }
                                .foregroundColor(Token.white.swiftUIColor.opacity(0.8))
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Token.black.swiftUIColor.ignoresSafeArea())
            .navigationTitle("Racquet Head Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Token.black.swiftUIColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Token.primary100.swiftUIColor)
                }
            }
        }
    }
}

#Preview {
    RacquetHeadArticleSheet()
} 
