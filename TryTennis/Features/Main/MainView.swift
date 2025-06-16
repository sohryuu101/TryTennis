import SwiftUI

struct MainView: View {
    var body: some View {
        NavigationStack{
            ZStack{
                RadialGradient(
                    colors: [Color(red: 10 / 255, green: 45 / 255, blue: 7 / 255), .black],
                    center: UnitPoint(x: 0.5, y: 0.1),
                    startRadius: 0,
                    endRadius: 1100
                )
                .ignoresSafeArea(edges: .all)
                
                VStack{
                    ZStack {
                        HStack {
                            Spacer()
                            Image("IconTransparent")
                                .resizable()
                                .frame(width: 50, height: 50)
                            Spacer()
                        }
                        
                        HStack{
                            Spacer()
                            
                            NavigationLink(destination: SessionHistoryView()){
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    NavigationLink(destination: LiveAnalysisView()){
                        ZStack{
                            Image("LiveAnalysis")
                                .resizable()
                                .cornerRadius(10)
                            
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, Color.black.opacity(0.6)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .cornerRadius(10)
                            
                            VStack(alignment: .leading){
                                Spacer()
                                Text("Live Analysis")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Color.white)
                                
                                Text("Improve your forehand stroke with instant feedback. Track your progress and adjust your technique with live analysis")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color.white)
                                    .multilineTextAlignment(.leading)
                                
                                HStack{
                                    Spacer()
                                    Text("Start Analyzing")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(Color.white)
                                    
                                    Spacer()
                                        .frame(width: 8)
                                    
                                    Image(systemName: "arrow.right")
                                        .foregroundColor(Color.white)
                                    Spacer()
                                }
                                .padding(.vertical, 16)
                            }
                            .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                    }
                    .padding(.top, 30)
                    
                    NavigationLink(destination: ImagePickerView()){
                        ZStack{
                            Image("GripClassifierImage")
                                .resizable()
                                .cornerRadius(10)
                            
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, Color.black.opacity(0.6)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .cornerRadius(10)
                            
                            VStack(alignment: .leading){
                                Spacer()
                                Text("Grip Analysis")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Color.white)
                                
                                Text("Learn how to adjust your grip for more consistent and accurate shots. Get feedback to optimize your hold and take control of every shot")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color.white)
                                    .multilineTextAlignment(.leading)
                                
                                HStack{
                                    Spacer()
                                    Text("Check My Grip")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(Color.white)
                                    
                                    Spacer()
                                        .frame(width: 8)
                                    
                                    Image(systemName: "arrow.right")
                                        .foregroundColor(Color.white)
                                    Spacer()
                                }
                                .padding(.vertical, 16)
                            }
                            .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .padding(.top, 16)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .tint(Color(red: 249/255, green: 122/255, blue: 0/255))
        .orientationLock(.portrait)
    }
}

#Preview {
    MainView()
}
