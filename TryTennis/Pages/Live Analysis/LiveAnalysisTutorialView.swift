import SwiftUI

struct LiveAnalysisTutorialView: View{
    @State var currentTab: Int = 0
    
    let videoGuide: [Guide] = [
        Guide(image: TryTennisIcon.videoGuide1, title: "Connect to Apple Watch"),
        Guide(image: TryTennisIcon.videoGuide2, title: "Place your camera in a fixed position"),
    ]
    
    var body: some View {
        ZStack{
            Token.black.swiftUIColor
                .edgesIgnoringSafeArea(.all)
            
            
            VStack(alignment: .leading) {
                ForEach(videoGuide) { guide in
                    HStack{
                        guide.image.swiftUIImage
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70, height: 70)
                            .padding(.trailing, 16)
                        
                        Text(guide.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Token.white.swiftUIColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Token.gray50.swiftUIColor)
                    .cornerRadius(10)
                }
                
                Text("Ensure the net and player are visible")
                    .foregroundStyle(Token.white.swiftUIColor)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                TryTennisIcon.videoGuide3.swiftUIImage
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                
                Spacer()
                
                NavigationLink(destination: LiveAnalysisView()){
                    Text("Start Live Analysis")
                        .foregroundStyle(Token.white.swiftUIColor)
                        .font(.system(size: 20, weight: .semibold))
                        .padding(.vertical, 9.5)
                        .frame(maxWidth: .infinity)
                        .background(Token.accent500.swiftUIColor)
                        .cornerRadius(50)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
            .padding(.horizontal)
            .navigationTitle("Live Analysis Guide")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            AppDelegate.orientation = .portrait
        }
    }
}
