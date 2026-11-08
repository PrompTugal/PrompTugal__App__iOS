import Observation
import SwiftUI
import UIKit

/// What the external display shows. The presenter console sets `slide`; the window on the external
/// display (or the AirPlay screen) follows it. With nothing set, the display shows a blank screen.
@MainActor @Observable
public final class PresenterOutput {
    public static let shared = PresenterOutput()

    public struct Frame: Equatable {
        public var slide: DeckSlide
        public var deckTitle: String
        public var position: String
    }

    public var frame: Frame?
    /// True while an external display scene is connected.
    public private(set) var isConnected = false
    var store: DeckStore?

    fileprivate func setConnected(_ value: Bool) { isConnected = value }
}

/// The view on the external display: the current slide, full screen, on black.
struct ExternalSlideView: View {
    let output: PresenterOutput

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let frame = output.frame {
                SlideCanvas(slide: frame.slide, deckTitle: frame.deckTitle, position: frame.position, store: output.store)
            }
        }
    }
}

/// The scene delegate for the external display. The app opts in by declaring a scene configuration for the
/// role `UIWindowSceneSessionRoleExternalDisplayNonInteractive` whose delegate class is
/// `PTDeck.ExternalDisplaySceneDelegate`, in the scene manifest of its Info.plist. Without that, iOS mirrors the iPad's
/// screen to the display (which still works, but shows the presenter console).
public final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    public var window: UIWindow?

    public func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: ExternalSlideView(output: .shared))
        window.isHidden = false
        self.window = window
        Task { @MainActor in PresenterOutput.shared.setConnected(true) }
    }

    public func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        Task { @MainActor in PresenterOutput.shared.setConnected(false) }
    }
}
