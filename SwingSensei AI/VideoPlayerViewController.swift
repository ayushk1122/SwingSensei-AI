import UIKit
import AVKit

class VideoPlayerViewController: UIViewController {
    var videoURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupVideoPlayer()
    }

    private func setupVideoPlayer() {
        guard let url = videoURL else {
            print("Error: No video URL provided.")
            return
        }

        let player = AVPlayer(url: url)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.view.frame = view.bounds

        addChild(playerViewController)
        view.addSubview(playerViewController.view)
        playerViewController.didMove(toParent: self)

        player.play()

        setupButtons()
    }

    private func setupButtons() {
        let retakeButton = UIButton(type: .system)
        retakeButton.setTitle("Retake", for: .normal)
        retakeButton.addTarget(self, action: #selector(retakeTapped), for: .touchUpInside)
        retakeButton.frame = CGRect(x: 50, y: view.bounds.height - 100, width: 100, height: 50)
        retakeButton.backgroundColor = .yellow
        retakeButton.setTitleColor(.black, for: .normal)
        view.addSubview(retakeButton)

        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Save", for: .normal)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.frame = CGRect(x: view.bounds.width - 150, y: view.bounds.height - 100, width: 100, height: 50)
        saveButton.backgroundColor = .green
        saveButton.setTitleColor(.white, for: .normal)
        view.addSubview(saveButton)
    }

    @objc private func retakeTapped() {
        NotificationCenter.default.post(name: NSNotification.Name("retakeVideo"), object: nil)
        dismiss(animated: true, completion: nil)
    }

    @objc private func saveTapped() {
        guard let url = videoURL else { return }
        UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
        NotificationCenter.default.post(name: NSNotification.Name("videoSaved"), object: nil)
        dismiss(animated: true, completion: nil)
    }
}
