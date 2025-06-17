import SwiftUI

struct LiveAnalysisTutorialView: View{
    @State var currentTab: Int = 0
    
    let photoGuideTutorial: [Guide] = [
        Guide(image: "video_guide_1", title: "Use a tennis ball and racquet", description: "Make sure the ball racquet is fully visible in screen"),
        Guide(image: "video_guide_2", title: "Keep whole body visible", description: "Make sure your full body fits in the screen"),
        Guide(image: "video_guide_3", title: "Use right hand", description: "For better accuracy, please use your right hand"),
        Guide(image: "video_guide_4", title: "Make sure the lighting is bright enough", description: "Avoid shadows that cover details.")
    ]
    
    let photoGuideTutorial_2: [Guide] = [
        Guide(image: "video_guide_5", title: "Use Forehand Stroke", description: "For better analysis, use forehand grip using your right hand"),
        Guide(image: "video_guide_6", title: "Record from your right side", description: "This side view helps the AI detect your movement more accurately"),
    ]
    
    var body: some View {
        ZStack{
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            VStack{
                TabView(selection: $currentTab){
                    VStack(alignment: .leading) {
                        Text("To help AI analyze your grip more accurately, please follow these guides")
                            .foregroundStyle(Color.white)
                            .font(.system(size: 16, weight: .regular))
                        
                        ForEach(photoGuideTutorial) { guide in
                            HStack{
                                Image(guide.image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 70, height: 70)
                                    .padding(.trailing, 16)
                                
                                VStack(alignment: .leading) {
                                    Text(guide.title)
                                        .font(.system(size: 15, weight: .semibold))
                                    
                                    Text(guide.description)
                                        .font(.system(size: 13, weight: .regular))
                                }
                                .foregroundStyle(Color.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(red: 65 / 255, green: 65 / 255, blue: 65 / 255))
                            .cornerRadius(10)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .tag(0)
                    
                    VStack(alignment: .leading) {
                        ForEach(photoGuideTutorial_2) { guide in
                            HStack(){
                                Image(guide.image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 70, height: 70)
                                    .padding(.trailing, 16)
                                
                                VStack(alignment: .leading) {
                                    Text(guide.title)
                                        .font(.system(size: 15, weight: .semibold))
                                    
                                    Text(guide.description)
                                        .font(.system(size: 13, weight: .regular))
                                }
                                .foregroundStyle(Color.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(red: 65 / 255, green: 65 / 255, blue: 65 / 255))
                            .cornerRadius(10)
                        }
                        
                        Text("Here’s the example for your reference")
                            .foregroundStyle(Color.white)
                            .font(.system(size: 16, weight: .regular))
                        
                        HStack{
                            Spacer()
                            Image("video_guide_7")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 185)
                            Spacer()
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.5), value: currentTab)
                
                Spacer().frame(height: 16)

                HStack(spacing: 12) {
                    ForEach(0...1, id: \.self) { index in
                        Circle()
                            .fill(currentTab == index ? Color.white : Color(red: 84 / 255, green: 84 / 255, blue: 82 / 255))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(width: 50)
                .background(Color(red: 181 / 255, green: 180 / 255, blue: 175 / 255))
                .cornerRadius(50)
                
                Spacer().frame(height: 24)

                if currentTab == 1 {
                    NavigationLink(destination: LiveAnalysisView()){
                        Text("Start Live Analysis")
                            .foregroundStyle(Color.white)
                            .font(.system(size: 20, weight: .semibold))
                            .padding(.vertical, 9.5)
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 249 / 255, green: 122 / 255, blue: 0))
                            .cornerRadius(50)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                } else {
                    Spacer().frame(height: 60)
                }
            }
            .navigationTitle("Video Guide")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
