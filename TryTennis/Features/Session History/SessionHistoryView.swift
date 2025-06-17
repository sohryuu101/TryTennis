import SwiftUI
import SwiftData

struct SessionHistoryView: View {
    @Query(sort: \Session.timestamp, order: .reverse) private var sessions: [Session]
    
    var body: some View {
        ZStack {
            Color(red: 5 / 255, green: 44 / 255, blue: 6 / 255)
                .ignoresSafeArea(edges: .all)
            
            LinearGradient(
                colors: [Color(red: 5 / 255, green: 19 / 255, blue: 3 / 255),
                         Color(red: 8 / 255, green: 34 / 255, blue: 5 / 255)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if sessions.isEmpty {
                        Text("No sessions recorded yet.")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.headline)
                            .padding()
                    } else {
                        ForEach(sessions) { session in
                            SessionHistoryRow(session: session)
                        }
                    }
                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
                .navigationTitle("Session History")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color(red: 50 / 255.0, green: 95 / 255.0, blue: 44 / 255.0), for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .navigationDestination(for: Session.self) { session in
                    SessionDetailView()
                        .environment(SessionDetailViewModel(session: session))
                }
            }
        }
    }
}

struct SessionHistoryRow: View {
    let session: Session
    
    var body: some View {
        NavigationLink(value: session) {
            HStack {
                VStack(alignment: .leading) {
                    Text(session.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("Total Shots: \(session.totalAttempts)")
                        .font(.headline)
                        .foregroundColor(.black)
                    Text("Successful: \(session.successfulShots)")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    Text("Failed: \(session.failedShots)")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SessionHistoryView()
        .modelContainer(for: Session.self, inMemory: true)
}
