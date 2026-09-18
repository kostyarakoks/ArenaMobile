import Foundation
import Combine
import CoreGraphics

/// Placeholder game state — the seam where real game data will eventually live.
///
/// Today it only drives the toy demo in GameView (a ball bouncing across a Canvas, one
/// point per bounce), but the shape is deliberately generic: an ObservableObject with a
/// `tick(dt:)` entry point is the same pattern you'd use for a real game loop, whether the
/// simulation stays purely local or gets replaced by data pulled from a backend (e.g. polling
/// your Laravel API the way the web client already does for build queues / movements).
final class GameState: ObservableObject {
    @Published var isRunning = false
    @Published var score = 0

    // Normalized 0...1 horizontal position + velocity (units/second), consumed by GameView.
    @Published var playerX: CGFloat = 0.05
    @Published var playerVelocity: CGFloat = 0.35

    func start() {
        isRunning = true
        score = 0
        playerX = 0.05
        playerVelocity = abs(playerVelocity)
    }

    func stop() {
        isRunning = false
    }

    /// Called once per rendered frame by GameView's TimelineView. `dt` is the elapsed time in
    /// seconds since the previous tick — always integrate movement by `dt`, never by a fixed
    /// per-frame constant, or the game runs at different speeds on different devices/refresh
    /// rates (ProMotion iPhones render at up to 120 Hz).
    func tick(dt: TimeInterval) {
        guard isRunning else { return }

        playerX += playerVelocity * CGFloat(dt)

        if playerX >= 1 {
            playerX = 1
            playerVelocity = -abs(playerVelocity)
            score += 1
        } else if playerX <= 0 {
            playerX = 0
            playerVelocity = abs(playerVelocity)
            score += 1
        }
    }
}
