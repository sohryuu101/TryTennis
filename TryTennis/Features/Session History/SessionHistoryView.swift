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
                VStack(alignment: .leading, spacing: 24) {
                    Text("Session History")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.top, 8)

                    // Today
                    if !todaySessions.isEmpty {
                        Text("Today")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.top, 8)
                        ForEach(todaySessions) { session in
                            SessionHistoryRow(session: session, showTime: true)
                        }
                    }

                    // Past 7 Days
                    if !past7DaysSessions.isEmpty {
                        Text("Past 7 Days")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.top, 8)
                        ForEach(past7DaysSessions) { session in
                            SessionHistoryRow(session: session, showTime: false)
                        }
                    }

                    // Past 12 Months
                    if !past12MonthsSessions.isEmpty {
                        Text("Past 12 Months")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.top, 8)
                        ForEach(past12MonthsSessions) { session in
                            SessionHistoryRow(session: session, showTime: false)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color(red: 50 / 255.0, green: 95 / 255.0, blue: 44 / 255.0), for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
        }
    }
    
    // Helper computed properties for grouping
    private var todaySessions: [Session] {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDateInToday($0.timestamp) }
    }
    private var past7DaysSessions: [Session] {
        let calendar = Calendar.current
        return sessions.filter {
            !calendar.isDateInToday($0.timestamp) &&
            (calendar.dateComponents([.day], from: $0.timestamp, to: Date()).day ?? 8) < 7
        }
    }
    private var past12MonthsSessions: [Session] {
        let calendar = Calendar.current
        return sessions.filter {
            !(calendar.isDateInToday($0.timestamp) ||
              (calendar.dateComponents([.day], from: $0.timestamp, to: Date()).day ?? 400) < 7) &&
            (calendar.dateComponents([.month], from: $0.timestamp, to: Date()).month ?? 13) < 12
        }
    }
}

struct SessionHistoryRow: View {
    let session: Session
    let showTime: Bool
    
    var body: some View {
        NavigationLink(destination: SessionDetailView(viewModel: SessionDetailViewModel(session: session))) {
            HStack {
                Text("\(session.successfulShots)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(red: 50/255, green: 95/255, blue: 44/255))
                Text("Successful Returns")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                Spacer()
                Text(showTime ? session.timestamp.formatted(date: .omitted, time: .shortened) : session.timestamp.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(red: 235/255, green: 243/255, blue: 233/255))
            .cornerRadius(18)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SessionHistoryView()
        .modelContainer(for: Session.self, inMemory: true)
}
