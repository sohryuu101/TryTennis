import SwiftUI

struct OnboardingView: View {
    @ObservedObject var splashScreenViewModel: SplashScreenViewModel
    
    var body: some View {
        ZStack{
            RadialGradient(
                colors: [Color(red: 9 / 255, green: 38 / 255, blue: 6 / 255), .black],
                center: UnitPoint(x: 1, y: 0.3),
                startRadius: 0,
                endRadius: 1000
            )
            .ignoresSafeArea(edges: .all)

            VStack{
                Image("IconTransparent")
                    .resizable()
                    .frame(width: 75, height: 75)
                
                Spacer()
                
                Text("Welcome to")
                    .font(.system(size: 28))
                    .foregroundColor(Color.white)
                
                Text("Try Tennis")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Color.white)

                Spacer()
                
                Button(action:{
                    splashScreenViewModel.changeOnboarding()
                }, label:{
                    HStack{
                        Spacer()
                        Text("Start")
                            .font(.system(size: 17, weight: .regular))
                                  
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                        Spacer()
                    }
                    .foregroundColor(Color.black)
                    .frame(maxWidth: 95)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(99)
                })
            }
        }
    }
}
