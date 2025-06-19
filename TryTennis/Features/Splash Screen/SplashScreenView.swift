import SwiftUI

struct SplashScreenView: View{
    @StateObject private var viewModel: SplashScreenViewModel = SplashScreenViewModel()
    @State private var size = 0.7
    @State private var opacity: Double = 0.7
    
    var body: some View{
        if viewModel.isSplashScreenActive {
            ZStack{
                Color.black
                    .ignoresSafeArea(edges: .all)
                
                VStack(alignment: .center, spacing: 10){
                    VStack{
                        Image("IconTransparent")
                            .resizable()
                            .frame(width: 150, height: 160)
                        
                        Text("TryTennis")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color(red: 249/255, green: 122/255, blue: 0/255))
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
            MainView()
        }
    }
}

#Preview {
    SplashScreenView()
}
