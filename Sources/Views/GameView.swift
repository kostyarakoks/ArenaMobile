import SwiftUI

/// A minimal but REAL, on-device-tested game loop: TimelineView drives a Canvas redraw every
/// frame, GameState.tick(dt:) advances the simulation, Canvas just reads the current state and
/// paints it. This split (state / tick / draw) is the pattern to keep even as the game grows —
/// don't let Canvas mutate state directly, and don't let GameState know how to draw itself.
struct GameView: View {
    @EnvironmentObject private var state: GameState
    @State private var lastTick: Date?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Очки: \(state.score)")
                    .font(.headline)
                Spacer()
                Button(state.isRunning ? "Стоп" : "Старт") {
                    if state.isRunning {
                        state.stop()
                    } else {
                        state.start()
                        lastTick = nil
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

            TimelineView(.animation(paused: !state.isRunning)) { timeline in
                Canvas { context, size in
                    let radius: CGFloat = 18
                    let x = state.playerX * (size.width - radius * 2) + radius
                    let y = size.height / 2
                    let dot = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    context.fill(dot, with: .color(.orange))
                }
                .onChange(of: timeline.date) { newDate in
                    let dt = lastTick.map { newDate.timeIntervalSince($0) } ?? 0
                    lastTick = newDate
                    state.tick(dt: min(dt, 0.1)) // clamp so a dropped frame can't cause a huge jump
                }
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .frame(minHeight: 160)

            Text("""
            Демо-геймлуп: точка отскакивает от краёв канваса, каждое отражение — +1 очко. \
            Логика — в GameState.tick(dt:), рендер — в Canvas этого экрана.
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top)
    }
}

#Preview {
    GameView()
        .environmentObject(GameState())
}
