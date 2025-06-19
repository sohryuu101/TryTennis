import SwiftData
import SwiftUI

struct SessionHistoryView: View {
    @Query(sort: \Session.timestamp, order: .reverse) private var sessions: [Session]
    @StateObject private var viewModel: SessionHistoryViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: SessionHistoryViewModel(sessions: []))
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea(edges: .all)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Session History")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.top, 8)

                    // Today
                    if !viewModel.todaySessions.isEmpty {
                        Text("Today")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.top, 8)
                        ForEach(viewModel.todaySessions) { session in
                            SessionHistoryRow(session: session, showTime: true)
                        }
                    }

                    // Past 7 Days
                    if !viewModel.past7DaysSessions.isEmpty {
                        Text("Past 7 Days")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.top, 8)
                        ForEach(viewModel.past7DaysSessions) { session in
                            SessionHistoryRow(session: session, showTime: false)
                        }
                    }

                    // Past 12 Months
                    if !viewModel.past12MonthsSessions.isEmpty {
                        Text("Past 12 Months")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.top, 8)
                        ForEach(viewModel.past12MonthsSessions) { session in
                            SessionHistoryRow(session: session, showTime: false)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
        }
        .onChange(of: sessions) { newSessions in
            viewModel.sessions = newSessions
        }
        .onAppear {
            viewModel.sessions = sessions
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
