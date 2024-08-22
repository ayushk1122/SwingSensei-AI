import SwiftUI
import CoreData
import AVFoundation
import AVKit

struct ContentView: View {
    var body: some View {
        TabView {
            AnalyzeView()
                .tabItem {
                    Image(systemName: "camera")
                    Text("Analyze")
                }
            
            LearnView()
                .tabItem {
                    Image(systemName: "book")
                    Text("Learn")
                }
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person")
                    Text("Profile")
                }
        }
    }
}

struct HostedViewController: UIViewControllerRepresentable {
    @Binding var isRecording: Bool
    
    func makeUIViewController(context: Context) -> ViewController {
        let viewController = ViewController()
        context.coordinator.viewController = viewController
        return viewController
    }

    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        DispatchQueue.main.async {
            if isRecording {
                uiViewController.startRecording()
            } else {
                uiViewController.stopRecording()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        var viewController: ViewController?
    }
}

struct AnalyzeView: View {
    @State private var isRecording = false
    @State private var showVideoPlayer = false
    @State private var recordedVideoURL: URL? = nil

    var body: some View {
        ZStack {
            HostedViewController(isRecording: $isRecording)
                .ignoresSafeArea()

            if let url = recordedVideoURL, showVideoPlayer {
                VStack {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 300)

                    HStack {
                        Button(action: {
                            recordedVideoURL = nil
                            showVideoPlayer = false
                            isRecording = false
                        }) {
                            Text("Retake")
                                .font(.title)
                                .padding()
                                .background(Color.yellow)
                                .foregroundColor(.black)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            if url != URL(fileURLWithPath: "/dev/null") {
                                UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
                            }
                            showVideoPlayer = false
                        }) {
                            Text("Confirm")
                                .font(.title)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                }
                .transition(.move(edge: .bottom))
            } else {
                VStack {
                    Spacer()
                    Button(action: {
                        isRecording.toggle()
                    }) {
                        Circle()
                            .fill(isRecording ? Color.red : Color.white)
                            .frame(width: 70, height: 70)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                            )
                            .shadow(radius: 10)
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("videoRecorded"))) { _ in
            DispatchQueue.main.async {
                if let viewController = UIApplication.shared.windows.first?.rootViewController as? ViewController {
                    if let url = viewController.playbackURL {
                        recordedVideoURL = url
                        showVideoPlayer = true
                        print("Video successfully recorded and saved to URL: \(url)")
                    } else {
                        print("Error: No playback URL found.")
                    }
                } else {
                    print("Error: Could not access root view controller.")
                }
            }
        }
    }
}

struct LearnView: View {
    var body: some View {
        VStack {
            Text("Learn to Improve")
                .font(.largeTitle)
                .padding()
            Spacer()
        }
        .navigationTitle("Learn")
    }
}

struct ProfileView: View {
    var body: some View {
        VStack {
            Text("Your Profile")
                .font(.largeTitle)
                .padding()
            Spacer()
        }
        .navigationTitle("Profile")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

