import SwiftUI

struct LiveAnalysisTutorialView: View{
    @State var currentTab: Int = 0
    
    let videoGuide: [Guide] = [
        Guide(image: "video_guide_1", title: "Connect to Apple Watch"),
        Guide(image: "video_guide_2", title: "Place your camera in a fixed position"),
    ]
    
    var body: some View {
        ZStack{
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            
            VStack(alignment: .leading) {
                ForEach(videoGuide) { guide in
                    HStack{
                        Image(guide.image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70, height: 70)
                            .padding(.trailing, 16)
                        
                        Text(guide.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color("grayscale10"))
                    .cornerRadius(10)
                }
                
                Text("Ensure the net and player are visible")
                    .foregroundStyle(Color.white)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                Image("video_guide_3")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                
                Spacer()
                
                NavigationLink(destination: LiveAnalysisView()){
                    Text("Start Live Analysis")
                        .foregroundStyle(Color.white)
                        .font(.system(size: 20, weight: .semibold))
                        .padding(.vertical, 9.5)
                        .frame(maxWidth: .infinity)
                        .background(Color("primaryOrange"))
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
