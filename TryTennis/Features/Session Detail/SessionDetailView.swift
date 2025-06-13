import SwiftUI
import AVKit

struct SessionDetailView: View {
    var body: some View {
        ZStack{
            LinearGradient(
                colors: [Color(red: 50 / 255, green: 95 / 255, blue: 44 / 255), Color(red: 5 / 255, green: 19 / 255, blue: 3 / 255), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false){
                VStack(alignment: .leading){
                    HStack{
                        Text("June 12th, 2025")
                        Spacer()
                        Text("11.30")
                    }
                    .padding()
                    .foregroundColor(Color.white)
                    .background(Color(red: 249 / 255, green: 122 / 255, blue: 0))
                    .cornerRadius(10)
                    
                    HStack(spacing: 16) {
                        VStack{
                            Text("Total Success")
                            Text("21")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(10)

                        VStack{
                            Text("Total Fail")
                            Text("3")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(10)
                    }
                    .foregroundColor(Color.black)
                    .padding(.top, 16)
                    
                    HStack(spacing: 16) {
                        VStack{
                            Text("Play Duration")
                            Text("10:01")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(10)

                        VStack{
                            Text("Total Attempts")
                            Text("24")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(10)
                    }
                    .foregroundColor(Color.black)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    
                    Text("Performance Review")
                        .foregroundColor(Color.white)
                        .font(.system(size: 28, weight: .bold))
                    
                    TabView {
                        VideoPlayer(player: AVPlayer(url: Bundle.main.url(forResource: "video1", withExtension: "mp4")!))
                            .frame(height: 200)
                            .cornerRadius(12)
                            .padding(.top, 10)

                        VideoPlayer(player: AVPlayer(url: Bundle.main.url(forResource: "video2", withExtension: "mp4")!))
                            .frame(height: 200)
                            .cornerRadius(12)
                            .padding(.top, 10)
                    }
                    .frame(height: 200)
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                }
                .padding(.horizontal)
                .navigationTitle("Session Detail")
            }
        }
    }
}

#Preview {
    NavigationStack{
        SessionDetailView()
    }
}
