import UIKit

/// The two-pane Duo layout is for the iPhone Duo's inner display. An iPad is
/// regular width too, and keeps its own single-window layout.
@MainActor
enum DeviceIdiom {
    static var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
}
