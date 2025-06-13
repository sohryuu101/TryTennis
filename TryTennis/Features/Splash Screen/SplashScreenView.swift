import SwiftUI

struct SplashScreenView: View{
    @StateObject private var viewModel: SplashScreenViewModel = SplashScreenViewModel()
    @State private var size = 0.7
    @State private var opacity: Double = 0.7
    
    var body: some View{
        if viewModel.isSplashScreenActive {
            ZStack{
                Color(red: 10 / 255, green: 44 / 255, blue: 6 / 255)
                    .ignoresSafeArea(edges: .all)
                
                VStack(alignment: .center, spacing: 10){
                    VStack{
                        Image("TryTennisIcon")
                            .resizable()
                            .frame(width: 200, height: 200)
                        
                        Text("TryTennis")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(red: 249/255, green: 122/255, blue: 0/255))
                    }
                    .scaleEffect(size)
                    .opacity(opacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 0.5)) {
                            self.size = 1.3
                            self.opacity = 1
                        }
                    }
                }
                .onAppear{
                    viewModel.dismissSplashScreen()
                }
            }
        } else {
            if !viewModel.isOnboardingActive {
                MainView()
            } else {
                OnboardingView(splashScreenViewModel: viewModel)
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
