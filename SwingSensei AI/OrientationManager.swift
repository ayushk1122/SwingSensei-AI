import SwiftUI
import Combine

class OrientationManager: ObservableObject {
    @Published var orientation: UIDeviceOrientation = UIDevice.current.orientation
    
    private var cancellable: AnyCancellable?
    
    init() {
        cancellable = NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .compactMap { notification in
                return UIDevice.current.orientation
            }
            .assign(to: \.orientation, on: self)
    }
    
    deinit {
        cancellable?.cancel()
    }
}
