import SwiftUI
import CoreML
import Vision

struct GripClassifierView: View {
    @StateObject var viewModel: GripClassifierViewModel = GripClassifierViewModel()
    @State var currentTab: Int = 0
    
    var body: some View {
        ZStack{
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            VStack{
                TabView(selection: $currentTab){
                    VStack(alignment: .leading) {
                        Text("To help AI analyze your grip more accurately, please follow these guides")
                            .foregroundColor(Color.white)
                        
                        ForEach(viewModel.photoGuideTutorial) { guide in
                            HStack(){
                                Image(guide.image)
                                    .resizable()
                                    .frame(width: 70, height: 70)
                                    .aspectRatio(contentMode: .fill)
                                    .padding(.trailing, 16)
                                
                                VStack(alignment: .leading) {
                                    Text(guide.title)
                                    Text(guide.description)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(Color.white)
                            .background(Color(red: 65 / 255, green: 65 / 255, blue: 65 / 255))
                            .cornerRadius(10)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .navigationTitle("Photo Guide")
                    .navigationBarTitleDisplayMode(.large)
                    .tag(0)
                    
                    VStack(alignment: .leading) {
                        ForEach(viewModel.forehandGrip) { guide in
                            HStack(){
                                Image(guide.image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 70, height: 70)
                                    .padding(.trailing, 16)
                                
                                VStack(alignment: .leading) {
                                    Text(guide.title)
                                    Text(guide.description)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(Color.white)
                            .background(Color(red: 65 / 255, green: 65 / 255, blue: 65 / 255))
                            .cornerRadius(10)
                        }
                        
                        Text("Here’s the example for your reference")
                            .foregroundColor(Color.white)
                        
                        HStack{
                            
                            Spacer()
                            Image("forehand_grip_3")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 246)
                            
                            Spacer()
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .navigationTitle("Forehand Grip")
                    .navigationBarTitleDisplayMode(.large)
                    .tag(1)
                    .fullScreenCover(isPresented: $viewModel.showCamera) {
                        ImagePicker(image: $viewModel.image, showResult: $viewModel.showPhotoResult)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentTab)
                
                HStack(spacing: 12) {
                    ForEach(0...1, id: \.self) { index in
                        Circle()
                            .fill(currentTab == index ? Color.white : Color(red: 84 / 255, green: 84 / 255, blue: 82 / 255))
                            .frame(width: 12, height: 12)
                    }
                }
                .padding()
                .frame(minWidth: 50)
                .background(Color(red: 181 / 255, green: 180 / 255, blue: 175 / 255))
                .cornerRadius(50)
                
                if currentTab == 1 {
                    Button(action: {
                        viewModel.takePhoto()
                        print("Clicked")
                    }, label:{
                        Text("Start Photo")
                            .foregroundColor(Color.white)
                            .font(.system(size:25, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 249 / 255, green: 122 / 255, blue: 0))
                            .cornerRadius(50)
                            .padding(.horizontal)
                            .padding(.bottom)
                    })
                } else {
                    Spacer(minLength: 70)
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.showPhotoResult) {
            if let image = viewModel.image {
                if viewModel.classificationResult.count > 0 {
                    VStack(alignment: .leading){
                        Button(action:{
                            viewModel.closeResult()
                        }, label:{
                            Image(systemName: "xmark")
                                .foregroundColor(Color(red: 249 / 255, green: 122 / 255, blue: 0))
                        })
                        
                        VStack{
                            Text(viewModel.classificationResult[0])
                                .font(.system(size: 28, weight: .bold))
                                .multilineTextAlignment(.center)

                            Text(viewModel.classificationResult[1])
                                .font(.system(size: 17, weight: .regular))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        
                        HStack{
                            Spacer()
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 400)
                                .cornerRadius(20)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        
                        HStack{
                            VStack(alignment: .leading){
                                Text("Analyzed By AI")
                                    .font(.system(size: 15, weight: .semibold))
                                
                                Text("This score is estimated by AI. For accurate results, ensure to follow the guide closely")
                                    .font(.system(size: 13, weight: .regular))
                            }
                            
                            Spacer().frame(width: 15)
                            
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 5)
                                    .frame(width: 60, height: 60)

                                Circle()
                                    .trim(from: 0, to: Double(viewModel.result) / 100)
                                    .stroke(
                                        Color.orange,
                                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 58, height: 58)
                                
                                Text("\(viewModel.result)")
                                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button(action:{
                            viewModel.takePhoto()
                        }, label: {
                            Text("Analyze Again")
                                .font(.system(size: 25, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color(red: 249 / 255, green: 122 / 255, blue: 0))
                                .cornerRadius(60)
                        })
                    }
                    .padding()
                }
                else{
                    ProgressView()
                }
            } else {
                Text("No image captured.")
                    .padding()
            }
        }
    }
}

#Preview {
    NavigationStack{
        GripClassifierView()
    }
}
