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
                            .foregroundColor(Color(red: 220/255, green: 243/255, blue: 220/255))
                        Text("The racquet head angle is the tilt of your racquet head when making **contact** with the ball. This angle affects where the ball goes and how it behaves.")
                            .foregroundColor(.white)
                            .font(.body)
                    }
                    Divider().background(Color.white.opacity(0.2))
                    Group {
                        Text("Watch This Example")
                            .font(.title3).bold()
                            .foregroundColor(Color(red: 220/255, green: 243/255, blue: 220/255))
                        Text("See the correct racquet head angle from a side angle.")
                            .foregroundColor(.white)
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 180)
                            Image(systemName: "play.circle.fill")
                                .resizable()
                                .frame(width: 48, height: 48)
                                .foregroundColor(Color(white: 0.7))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Proper Forehand Contact — Racquet Face Angle")
                                .font(.headline)
                                .foregroundColor(.white)
                            HStack(spacing: 12) {
                                Label("Duration: 1:20", systemImage: "clock")
                                    .foregroundColor(.white.opacity(0.8))
                                Label("Filmed from the same angle used in TryTennis Live Analysis", systemImage: "mappin.and.ellipse")
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Racquet Head Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 220/255, green: 243/255, blue: 220/255))
                }
            }
        }
    }
}

#Preview {
    RacquetHeadArticleSheet()
} 
