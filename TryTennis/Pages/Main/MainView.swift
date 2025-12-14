import SwiftUI

struct MainView: View {
    var body: some View {
        VStack(alignment: .leading){
            Text("Live Analysis")
                .font(.system(size: 34, weight: .semibold))
                .padding()
            
            VStack(alignment: .center){
                HStack{
                    Spacer()
                    
                    ZStack{
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Token.bestSeller.swiftUIColor,
                                Token.black.swiftUIColor]),
                            center: .center,
                            startRadius: 5,
                            endRadius: 150
                        )
                        .frame(height: UIScreen.main.bounds.width * 0.55)
                        
                        TryTennisIcon.mascot.swiftUIImage
                            .resizable()
                            .scaledToFit()
                            .frame(width: UIScreen.main.bounds.width * 0.34, height: UIScreen.main.bounds.width * 0.55)
                    }
                    .padding(.vertical)
                    
                    Spacer()
                }
                
                Text("Hey! Let’s break down your stroke.")
                    .foregroundStyle(Token.white.swiftUIColor)
                    .font(.system(size: 15, weight: .regular))
                
                Text("Let’s see what your swing’s really made of.")
                    .foregroundStyle(Token.white.swiftUIColor)
                    .font(.system(size: 15, weight: .regular))
                
                NavigationLink(destination: LiveAnalysisTutorialView()) {
                    Text("Start Analyzing")
                        .foregroundColor(Token.white.swiftUIColor)
                        .font(.system(size: 15, weight: .bold))
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Token.accent500.swiftUIColor)
                        .cornerRadius(99)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 28)
            
            NavigationLink(destination: GripClassifierView()){
                HStack{
                    VStack(alignment: .leading){
                        HStack{
                            TryTennisIcon.grip.swiftUIImage
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 25)
                            
                            Text("Grip Analysis")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(Token.white.swiftUIColor)
                            Spacer()
                        }
                        
                        Text("Snap a pic of your grip")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Token.white.swiftUIColor)
                        
                    }
                    
                    Spacer()
                    
                    TryTennisIcon.arrowRight.swiftUIImage
                        .foregroundStyle(Token.white.swiftUIColor)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Token.gray50.swiftUIColor)
                .cornerRadius(20)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .toolbar{
            ToolbarItem(placement: .navigationBarTrailing){
                NavigationLink(destination: SessionHistoryView()){
                    HStack{
                        TryTennisIcon.history.swiftUIImage
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        
                        Text("History")
                            .font(.system(size: 17, weight: .regular))
                    }
                    .foregroundStyle(Token.white.swiftUIColor)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Token.gray200.swiftUIColor)
                    .cornerRadius(20)
                }
            }
        }
    }
}
