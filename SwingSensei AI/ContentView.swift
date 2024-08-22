import SwiftUI
import CoreData
import AVFoundation
import AVKit
import MobileCoreServices
import Foundation

struct IdentifiableVideo: Identifiable {
    let id = UUID()
    let url: URL
    var name: String
    var thumbnail: UIImage?
}

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

            LibraryView()
                .tabItem {
                    Image(systemName: "photo.on.rectangle")
                    Text("Library")
                }
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person")
                    Text("Profile")
                }
        }
    }
}


struct LibraryView: View {
    @State private var videos: [IdentifiableVideo] = []
    @State private var showVideoPicker = false
    @State private var selectedVideo: IdentifiableVideo?
    @State private var newVideoName = ""

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(videos) { video in
                        HStack {
                            if let thumbnail = video.thumbnail {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(8)
                            }
                            VStack(alignment: .leading) {
                                Text(video.name)
                                    .font(.headline)
                                Text(video.url.lastPathComponent)
                                    .font(.subheadline)
                            }
                            Spacer()
                            Button(action: {
                                deleteVideo(video)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        .onTapGesture {
                            selectedVideo = video
                        }
                    }
                    .onDelete(perform: delete)
                }

                Button(action: {
                    showVideoPicker = true
                }) {
                    Text("Upload Video")
                        .font(.title)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .navigationTitle("Library")
            .sheet(isPresented: $showVideoPicker) {
                VideoPicker(videos: $videos)
            }
            .sheet(item: $selectedVideo) { video in
                VideoPlayer(player: AVPlayer(url: video.url))
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .onAppear {
            loadVideos()
        }
    }
    
    func loadVideos() {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            videos = files.filter { $0.pathExtension == "mov" }.map { url in
                let name = url.deletingPathExtension().lastPathComponent
                let thumbnail = generateThumbnail(url: url)
                return IdentifiableVideo(url: url, name: name, thumbnail: thumbnail)
            }
        } catch {
            print("Error loading videos: \(error.localizedDescription)")
        }
    }
    
    func generateThumbnail(url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Error generating thumbnail: \(error.localizedDescription)")
            return nil
        }
    }

    private func deleteVideo(_ video: IdentifiableVideo) {
        do {
            try FileManager.default.removeItem(at: video.url)
            videos.removeAll { $0.id == video.id }
        } catch {
            print("Error deleting video: \(error.localizedDescription)")
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let video = videos[index]
            deleteVideo(video)
        }
    }
}


struct VideoPicker: UIViewControllerRepresentable {
    @Binding var videos: [IdentifiableVideo]
    @Environment(\.presentationMode) var presentationMode
    @State private var newVideoName: String = ""

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.mediaTypes = [kUTTypeMovie as String]
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: VideoPicker

        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let url = info[.mediaURL] as? URL {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.parent.promptForVideoName(url: url)
                }
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }

    func promptForVideoName(url: URL) {
        let alert = UIAlertController(title: "Name Your Video", message: "Please enter a name for your video.", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Video name"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            presentationMode.wrappedValue.dismiss()
        })
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let name = alert.textFields?.first?.text, !name.isEmpty {
                newVideoName = name
                addVideoWithName(url: url)
            }
        })

        DispatchQueue.main.async {
            if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                rootViewController.present(alert, animated: true, completion: nil)
            } else {
                print("Error: Could not access root view controller.")
            }
        }
    }

    func addVideoWithName(url: URL) {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let newURL = documentsDirectory.appendingPathComponent("\(newVideoName).mov")
        
        do {
            try fileManager.copyItem(at: url, to: newURL)
            let thumbnail = generateThumbnail(url: newURL)
            let identifiableVideo = IdentifiableVideo(url: newURL, name: newVideoName, thumbnail: thumbnail)
            videos.append(identifiableVideo)
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving video: \(error.localizedDescription)")
        }
    }

    func generateThumbnail(url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Error generating thumbnail: \(error.localizedDescription)")
            return nil
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
    @State private var showCameraPreview = false
    @State private var recordedVideoURL: URL? = nil

    var body: some View {
        ZStack {
            if showCameraPreview {
                HostedViewController(isRecording: $isRecording)
                    .ignoresSafeArea()
                    .transition(.move(edge: .bottom))
                
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
            } else {
                VStack {
                    Text("Analyze Your Swing")
                        .font(.largeTitle)
                        .padding()

                    Button(action: {
                        withAnimation {
                            showCameraPreview = true
                        }
                    }) {
                        Text("Record Swing")
                            .font(.title)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }

            if let url = recordedVideoURL, !isRecording {
                VStack {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 300)

                    HStack {
                        Button(action: {
                            // Clear the recorded video URL so it doesn't get saved to the library
                            recordedVideoURL = nil
                            showCameraPreview = false
                        }) {
                            Text("Retake")
                                .font(.title)
                                .padding()
                                .background(Color.yellow)
                                .foregroundColor(.black)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            // Only save to the library when the Save button is pressed
                            if let saveURL = recordedVideoURL, saveURL != URL(fileURLWithPath: "/dev/null") {
                                UISaveVideoAtPathToSavedPhotosAlbum(saveURL.path, nil, nil, nil)
                            }
                            // Clear the video URL after saving
                            recordedVideoURL = nil
                            showCameraPreview = false
                        }) {
                            Text("Save")
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
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("videoRecorded"))) { _ in
            DispatchQueue.main.async {
                if let viewController = UIApplication.shared.windows.first?.rootViewController as? ViewController {
                    if let url = viewController.playbackURL {
                        recordedVideoURL = url
                        showCameraPreview = false
                        isRecording = false
                        print("Video successfully recorded and saved to URL: \(url)")
                    } else {
                        print("Error: No playback URL found.")
                    }
                } else {
                    print("Error: Could not access root view controller.")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("retakeVideo"))) { _ in
            showCameraPreview = false
            recordedVideoURL = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("videoSaved"))) { _ in
            showCameraPreview = false
            recordedVideoURL = nil
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

