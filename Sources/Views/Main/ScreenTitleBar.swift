import SwiftUI

/// Small in-content replacement for a screen's native `.navigationTitle` + `.toolbar` action
/// button, for the handful of screens that had a REAL action button living in their native
/// navigation bar (MarketView's village switcher, AllianceView's "create alliance" plus button,
/// RallyPointView's "Обучение" button, MessagesView's compose button) — see GameTheme.swift's
/// own `gameNavBarHidden()` doc comment for why the native bar is now hidden everywhere (it was
/// doubling up with/overlapping GameHeaderBar). Everywhere else, hiding the native bar just
/// means the screen loses a redundant title (GameHeaderBar already establishes "who/what you're
/// looking at" on every screen) — only these four actually needed their button relocated
/// somewhere. Styled to match GameHeaderBar's own navy/amber panel language rather than
/// introducing a third visual style.
struct ScreenTitleBar<Trailing: View>: View {
    let title: String
    // `@ViewBuilder` belongs on the INIT PARAMETER (below), not this stored property — it's the
    // parameter that needs to turn a multi-statement/`if`-containing trailing closure literal
    // into a single View at the CALL SITE; the property itself just holds the already-built
    // closure value afterwards, same as every other container view in this codebase (see
    // ZoomableMapContainer's `content: () -> Content` for the identical pattern).
    let trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(GameTheme.amber)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            GameTheme.panelTop
                .overlay(alignment: .bottom) {
                    Rectangle().fill(GameTheme.panelBorder).frame(height: 1)
                }
        )
    }
}

extension ScreenTitleBar where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}
