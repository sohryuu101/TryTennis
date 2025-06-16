import SwiftUI

struct SessionHistoryView: View {
    @StateObject var viewModel: SessionHistoryViewModel = SessionHistoryViewModel()

    init(){
        let backgroundColor = UIColor(red: 50 / 255.0, green: 95 / 255.0, blue: 44 / 255.0, alpha: 1)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.backgroundColor = backgroundColor
        UINavigationBar.appearance().standardAppearance = appearance
        

        let scrollEdgeAppearance = UINavigationBarAppearance()
        scrollEdgeAppearance.configureWithTransparentBackground()
        scrollEdgeAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        scrollEdgeAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdgeAppearance
    }
    
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
                    Group {
                        Text("Today")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color.white)
                        
                        ForEach(0...3, id: \.self) { _ in
                            getSessionHistoryView()
                        }

                        Text("Last Week")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color.white)
                            .padding(.top, 5)
                        
                        ForEach(0...1, id: \.self) { _ in
                            getSessionHistoryView()
                        }

                        Text("Past Month")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color.white)
                            .padding(.top, 5)
                        
                        ForEach(0...2, id: \.self) { _ in
                            getSessionHistoryView()
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 20)
                }
                .navigationTitle("Session History")
                .navigationBarTitleDisplayMode(.large)
            }
        }
    }

    private func getSessionHistoryView() -> some View {
        let randomNumber = Int.random(in: 1...100)

        return NavigationLink(destination: SessionDetailView()) {
            HStack {
                Text("\(randomNumber) Successful Returns")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .foregroundColor(.black)
            .background(Color.white)
            .cornerRadius(10)
        }
    }
}

#Preview {
    SessionHistoryView()
}
