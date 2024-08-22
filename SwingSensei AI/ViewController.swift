import UIKit
import AVFoundation
import AVKit

class ViewController: UIViewController {
    private var permissionGranted = false
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var previewLayer = AVCaptureVideoPreviewLayer()
    private var movieOutput = AVCaptureMovieFileOutput()
    private var isRecording = false
    var playbackURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        checkPermission()
        
        sessionQueue.async { [unowned self] in
            guard permissionGranted else {
                print("Permission not granted.")
                return
            }
            self.setupCaptureSession()
            DispatchQueue.main.async {
                print("Starting capture session...")
                self.captureSession.startRunning()
            }
        }

        NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
        }
    }
    
    func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    func setupCaptureSession() {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Error: Could not access the camera.")
            return
        }
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("Error: Could not create video device input.")
            return
        }
        
        captureSession.beginConfiguration()

        if captureSession.canAddInput(videoDeviceInput) {
            captureSession.addInput(videoDeviceInput)
        }

        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        }

        captureSession.commitConfiguration()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("Error: ViewController instance is nil.")
                return
            }
            self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            self.previewLayer.videoGravity = .resizeAspectFill
            self.previewLayer.frame = self.view.layer.bounds
            self.view.layer.addSublayer(self.previewLayer)
            self.captureSession.startRunning()
        }
    }

    @objc func orientationChanged() {
        guard let connection = previewLayer.connection else {
            print("Error: Could not get preview layer connection.")
            return
        }
        
        switch UIDevice.current.orientation {
        case .portrait:
            connection.videoOrientation = .portrait
        case .landscapeRight:
            connection.videoOrientation = .landscapeLeft
        case .landscapeLeft:
            connection.videoOrientation = .landscapeRight
        case .portraitUpsideDown:
            connection.videoOrientation = .portraitUpsideDown
        default:
            connection.videoOrientation = .portrait
        }
        
        updatePreviewLayerFrame()
    }
    
    func updatePreviewLayerFrame() {
        previewLayer.frame = view.bounds
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePreviewLayerFrame()
    }

    func startRecording() {
        if !isRecording {
            let outputPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/slowMotion_\(Date().timeIntervalSince1970).mov"
            let outputFileURL = URL(fileURLWithPath: outputPath)

            let fileManager = FileManager.default
            let directory = outputFileURL.deletingLastPathComponent().path
            if !fileManager.fileExists(atPath: directory) {
                do {
                    try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
                    print("Directory created at: \(directory)")
                } catch {
                    print("Failed to create directory: \(error.localizedDescription)")
                }
            }
            
            print("Recording to: \(outputFileURL.path)")
            
            if fileManager.fileExists(atPath: outputFileURL.path) {
                try? fileManager.removeItem(at: outputFileURL)
            }
            
            movieOutput.startRecording(to: outputFileURL, recordingDelegate: self)
            isRecording = true
        }
    }

    func stopRecording() {
        if isRecording {
            movieOutput.stopRecording()
            isRecording = false
        }
    }
}

extension ViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording movie: \(error.localizedDescription)")
        } else {
            playbackURL = outputFileURL
            slowMotionProcessing(url: outputFileURL) { [weak self] processedURL in
                guard let self = self else {
                    print("Error: ViewController instance is nil during slow-motion processing.")
                    return
                }
                if let processedURL = processedURL {
                    self.playbackURL = processedURL
                    DispatchQueue.main.async {
                        self.presentVideoPlayer(url: processedURL)
                    }
                } else {
                    print("Error: Slow motion processing failed.")
                }
            }
        }
    }

    private func slowMotionProcessing(url: URL, completion: @escaping (URL?) -> Void) {
        let asset = AVAsset(url: url)
        let composition = AVMutableComposition()

        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            print("Error: No video track found")
            completion(nil)
            return
        }

        let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)

        do {
            try videoCompositionTrack?.insertTimeRange(timeRange, of: videoTrack, at: .zero)
            let scaleTimeRange = CMTimeRangeMake(start: .zero, duration: asset.duration)
            videoCompositionTrack?.scaleTimeRange(scaleTimeRange, toDuration: CMTimeMake(value: asset.duration.value * 2, timescale: asset.duration.timescale))

            let exportPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/slowMotionExport_\(Date().timeIntervalSince1970).mov"
            let exportURL = URL(fileURLWithPath: exportPath)

            print("Exporting to: \(exportURL.path)")

            let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
            exportSession?.outputURL = exportURL
            exportSession?.outputFileType = .mov

            exportSession?.exportAsynchronously {
                DispatchQueue.main.async {
                    switch exportSession?.status {
                    case .completed:
                        print("Export completed successfully to: \(exportURL.path)")
                        completion(exportURL)
                        
                        // Safely access the root view controller once after export
                        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                            // Use the rootViewController for further actions
                            print("Root view controller accessed successfully after export.")
                            // Here you can trigger the display of the playback view or other UI
                        } else {
                            print("Error: Could not access root view controller after export.")
                        }
                        
                    case .failed:
                        if let error = exportSession?.error {
                            print("Export failed: \(error.localizedDescription)")
                        } else {
                            print("Export failed: Unknown error")
                        }
                        completion(nil)
                        
                    case .cancelled:
                        print("Export cancelled")
                        completion(nil)
                        
                    default:
                        print("Export in progress")
                    }
                }
            }
        } catch {
            print("Error in slow motion processing: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
    private func presentVideoPlayer(url: URL) {
        let videoPlayerVC = VideoPlayerViewController()
        videoPlayerVC.videoURL = url
        DispatchQueue.main.async {
            self.present(videoPlayerVC, animated: true, completion: nil)
        }
    }
}
