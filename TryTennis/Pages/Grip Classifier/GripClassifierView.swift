import SwiftUI

struct GripClassifierView: View {
    @StateObject var viewModel = GripClassifierViewModel()
    
    let url = URL(string: "https://mytennishq.com/tennis-forehand-best-grips-tips-steps-with-photos/")
    
    var body: some View {
        ZStack{
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading) {
                ForEach(viewModel.gripGuide) { guide in
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
                Spacer()
                
                Button(action: {
                    viewModel.takePhoto()
                }, label:{
                    Text("Start Photo")
                        .foregroundStyle(Color.white)
                        .font(.system(size: 20, weight: .semibold))
                        .padding(.vertical, 9.5)
                        .frame(maxWidth: .infinity)
                        .background(Color("primaryOrange"))
                        .cornerRadius(50)
                        .padding(.horizontal)
                        .padding(.bottom)
                })
            }
            .padding(.horizontal)
            .navigationTitle("Grip Guide")
            .navigationBarTitleDisplayMode(.large)
        }
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            ImagePicker(image: $viewModel.image, showResult: $viewModel.showPhotoResult)
        }
        .fullScreenCover(isPresented: $viewModel.showPhotoResult) {
            if let image = viewModel.image {
                if viewModel.classificationResult.count > 0 {
                    VStack(alignment: .center){
                        HStack{
                            Button(action:{
                                viewModel.closeResult()
                            }, label:{
                                Image(systemName: "xmark")
                                    .foregroundStyle(Color("primaryOrange"))
                                    .font(.system(size: 20, weight: .semibold))
                            })
                            
                            Spacer()
                        }
                        
                        Text(viewModel.classificationResult[0])
                            .font(.system(size: 28, weight: .bold))
                        
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
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 5)
                                    .frame(width: 60, height: 60)

                                Circle()
                                    .trim(from: 0, to: Double(viewModel.result) / 100)
                                    .stroke(
                                        Color.white,
                                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 58, height: 58)
                                
                                Text("\(viewModel.result)%")
                                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.white)
                            }
                            
                            Spacer()
                                .frame(width: 12)
                            
                            Text(viewModel.classificationResult[1])
                                .font(.system(size: 17, weight: .regular))
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                        .padding(.vertical, 20)
                        .background(Color("newGray1"))
                        .cornerRadius(10)
                        
                        Spacer()
                        
                        Text("This number represents the estimated similarity to the")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color(red: 102 / 255, green: 102 / 255, blue: 102 / 255))
                        
                        if let safeURL = url {
                            Link("Eastern Forehand Grip", destination: safeURL)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(Color.blue)
                                .underline()
                                .padding(.bottom, 12)
                        } else {
                            Text("Eastern Forehand Grip")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(Color.blue)
                        }
                        
                        Button(action:{
                            viewModel.takePhoto()
                        }, label: {
                            Text("Analyze Again")
                                .font(.system(size: 20, weight: .semibold))
                                .padding(.vertical, 9.5)
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.white)
                                .background(Color("primaryOrange"))
                                .cornerRadius(60)
                                .padding(.bottom)
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

//#Preview {
//    NavigationStack{
//        GripClassifierView()
//    }
//}
