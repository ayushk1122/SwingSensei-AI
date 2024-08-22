import AVFoundation
import UIKit

class CameraManager: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    var captureSession: AVCaptureSession?
    var videoOutput: AVCaptureMovieFileOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var outputURL: URL?

    @Published var isRecording = false
    @Published var videoRecorded = false
    @Published var playbackURL: URL?

    override init() {
        super.init()
        setupCamera()
    }

    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Error: No video devices available")
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession?.canAddInput(videoInput) == true {
                captureSession?.addInput(videoInput)
            }
        } catch {
            print("Error: Could not create video input.")
            return
        }

        videoOutput = AVCaptureMovieFileOutput()
        if let videoOutput = videoOutput {
            if captureSession?.canAddOutput(videoOutput) == true {
                captureSession?.addOutput(videoOutput)
            }
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.videoGravity = .resizeAspectFill
    }

    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.startRunning()
        }
    }

    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.stopRunning()
        }
    }

    func startRecording() {
        guard let videoOutput = videoOutput else { return }
        isRecording = true
        outputURL = tempURL()
        videoOutput.startRecording(to: outputURL!, recordingDelegate: self)
    }

    func stopRecording() {
        videoOutput?.stopRecording()
        isRecording = false
    }

    func tempURL() -> URL {
        let directory = NSTemporaryDirectory() as NSString
        let path = directory.appendingPathComponent(UUID().uuidString + ".mov")
        return URL(fileURLWithPath: path)
    }

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        return previewLayer
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error finishing recording: \(error)")
            return
        }
        applySlowMotionEffect(to: outputFileURL) { slowMotionURL in
            DispatchQueue.main.async {
                self.playbackURL = slowMotionURL
                self.videoRecorded = true
            }
        }
    }

    func applySlowMotionEffect(to videoURL: URL, completion: @escaping (URL?) -> Void) {
        let videoAsset = AVURLAsset(url: videoURL)
        
        // Create a mutable composition
        let mixComposition = AVMutableComposition()
        
        // Add video track to the composition
        guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
            print("Error: Could not retrieve video track.")
            completion(nil)
            return
        }
        
        let compositionVideoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        do {
            try compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(start: .zero, duration: videoAsset.duration),
                                                       of: videoTrack,
                                                       at: .zero)
        } catch {
            print("Error inserting video track: \(error)")
            completion(nil)
            return
        }
        
        // Apply slow motion by scaling the time range
        let slowMotionFactor: Double = 2.0 // Adjust this factor to change slow-motion speed
        let videoDuration = videoAsset.duration
        compositionVideoTrack?.scaleTimeRange(CMTimeRangeMake(start: .zero, duration: videoDuration),
                                              toDuration: CMTimeMake(value: videoDuration.value * Int64(slowMotionFactor), timescale: videoDuration.timescale))
        
        // Export the composition to a new video file
        let outputURL = tempURL()
        guard let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else {
            print("Error: Could not create AVAssetExportSession.")
            completion(nil)
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(outputURL)
            case .failed:
                print("Export failed: \(exportSession.error?.localizedDescription ?? "unknown error")")
                completion(nil)
            default:
                print("Export session status: \(exportSession.status.rawValue)")
                completion(nil)
            }
        }
    }
}

