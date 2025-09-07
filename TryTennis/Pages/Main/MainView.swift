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
                                Color("additionalBrown"),
                                Color.black]),
                            center: .center,
                            startRadius: 5,
                            endRadius: 150
                        )
                        .frame(height: UIScreen.main.bounds.width * 0.55)
                        
                        Image("mascot")
                            .resizable()
                            .scaledToFit()
                            .frame(width: UIScreen.main.bounds.width * 0.34, height: UIScreen.main.bounds.width * 0.55)
                    }
                    .padding(.vertical)
                    
                    Spacer()
                }
                
                Text("Hey! Let’s break down your stroke.")
                    .foregroundStyle(Color.white)
                    .font(.system(size: 15, weight: .regular))
                
                Text("Let’s see what your swing’s really made of.")
                    .foregroundStyle(Color.white)
                    .font(.system(size: 15, weight: .regular))
                
                NavigationLink(destination: LiveAnalysisTutorialView()) {
                    Text("Start Analyzing")
                        .foregroundColor(.white)
                        .font(.system(size: 15, weight: .bold))
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color("primaryOrange"))
                        .cornerRadius(99)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 28)
            
            NavigationLink(destination: GripClassifierView()){
                HStack{
                    VStack(alignment: .leading){
                        HStack{
                            Image("grip")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 25)
                            
                            Text("Grip Analysis")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(Color.white)
                            Spacer()
                        }
                        
                        Text("Snap a pic of your grip")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color.white)
                        
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .foregroundStyle(Color.white)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color("grayscale10"))
                .cornerRadius(20)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .toolbar{
            ToolbarItem(placement: .navigationBarTrailing){
                NavigationLink(destination: SessionHistoryView()){
                    HStack{
                        Image("history")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        
                        Text("History")
                            .font(.system(size: 17, weight: .regular))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color("newGray2"))
                    .cornerRadius(20)
                }
            }
        }
    }
}
