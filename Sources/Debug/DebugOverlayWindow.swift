#if DEBUG
import SwiftUI
import UIKit

/// A plain SwiftUI `.overlay()` on RootView would sit *inside* the app's normal window, so
/// any `.sheet`/`.fullScreenCover` pushed from a deeper screen (there are several across the
/// app) would cover it. Putting NetworkDebugOverlay in its own UIWindow at `.alert + 1`
/// instead keeps the bubble/panel visible over literally everything, on every screen.
final class DebugOverlayWindow {
    static let shared = DebugOverlayWindow()

    private var window: PassthroughWindow?

    private init() {}

    func attach(to scene: UIWindowScene) {
        guard window == nil else { return }

        let overlayWindow = PassthroughWindow(windowScene: scene)
        overlayWindow.windowLevel = .alert + 1
        overlayWindow.backgroundColor = .clear

        let hosting = UIHostingController(rootView: NetworkDebugOverlay())
        hosting.view.backgroundColor = .clear
        overlayWindow.rootViewController = hosting
        overlayWindow.isHidden = false

        window = overlayWindow
    }
}

/// Only the overlay's own visible content (the bubble, or the expanded panel) intercepts
/// touches; everywhere else on screen, touches fall through to the app window underneath so
/// the debug window never blocks normal play.
private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        return hit == rootViewController?.view ? nil : hit
    }
}

/// Attach once the view is actually in a window scene — used from ArenaMobileApp so the
/// debug window exists for the whole app lifetime, from the splash screen onward.
struct NetworkDebugOverlayAttacher: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        DispatchQueue.main.async {
            if let scene = view.window?.windowScene {
                DebugOverlayWindow.shared.attach(to: scene)
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension View {
    /// Adds the invisible helper view that locates the window scene and mounts the floating
    /// network-debug window over the whole app. DEBUG-only (see this file's #if) — compiles
    /// to nothing in a release build.
    func networkDebugOverlay() -> some View {
        background(NetworkDebugOverlayAttacher())
    }
}
#else
import SwiftUI

extension View {
    func networkDebugOverlay() -> some View { self }
}
#endif
