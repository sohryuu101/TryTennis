import SwiftUI
import SwiftData

struct SessionHistoryView: View {
    @Query(sort: \Session.timestamp, order: .reverse) private var sessions: [Session]
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 50 / 255, green: 95 / 255, blue: 44 / 255),
                         Color(red: 5 / 255, green: 19 / 255, blue: 3 / 255),
                         Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("Today")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.white)
                        
                        ForEach(0...3, id: \.self) { _ in
                            getSessionHistoryView()
                        }

                        Text("Last Week")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.top, 5)
                        
                        ForEach(0...1, id: \.self) { _ in
                            getSessionHistoryView()
                        }

                        Text("Past Month")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.top, 5)
                        
                        ForEach(0...2, id: \.self) { _ in
                            getSessionHistoryView()
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
            .foregroundStyle(.black)
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
