import SwiftUI
import UIKit

/// Native equivalents of the web app's shared look — resources/css/app.css's body background,
/// `.tv-panel` / `.tv-btn` / `.tv-btn-secondary` / `.resource-pill` classes, and the
/// amber-on-navy palette every re-themed Vue page (Buildings/Fields/Market/Alliance/Reports/…)
/// already uses. Colors are transcribed from that stylesheet's exact hex values, not
/// approximated, so the native screens read as the same game instead of stock iOS chrome.
///
/// `configureGlobalAppearance()` (called once from RootView.init) handles the parts no
/// per-screen SwiftUI modifier reaches — UINavigationBar and the UITableView backing every
/// `List`/`.insetGrouped`/`.plain` screen in this app — so most existing List-based screens
/// pick up the dark-navy/panel look for free. `.preferredColorScheme(.dark)` (applied at the
/// RootView root) is what keeps default SwiftUI `.primary`/`.secondary` text legible on that
/// dark background everywhere else.
enum GameTheme {
    // body { background-color: #0a1730; }
    static let background = Color(red: 0x0a / 255.0, green: 0x17 / 255.0, blue: 0x30 / 255.0)

    // .tv-panel: bg-gradient-to-b from-[#152f57] to-[#0e2140], border-blue-900/50
    static let panelTop = Color(red: 0x15 / 255.0, green: 0x2f / 255.0, blue: 0x57 / 255.0)
    static let panelBottom = Color(red: 0x0e / 255.0, green: 0x21 / 255.0, blue: 0x40 / 255.0)
    static let panelBorder = Color(red: 0x1e / 255.0, green: 0x3a / 255.0, blue: 0x8a / 255.0).opacity(0.5)

    // text-amber-300 / text-amber-200 (headlines, bonus/effect callouts)
    static let amber = Color(red: 0xfc / 255.0, green: 0xd3 / 255.0, blue: 0x4d / 255.0)
    static let amberLight = Color(red: 0xfd / 255.0, green: 0xe6 / 255.0, blue: 0x8a / 255.0)

    // text-blue-50 / blue-200 / blue-300 (body text, secondary text, muted text)
    static let textPrimary = Color(red: 0xef / 255.0, green: 0xf6 / 255.0, blue: 0xff / 255.0)
    static let textSecondary = Color(red: 0xbf / 255.0, green: 0xdb / 255.0, blue: 0xfe / 255.0)
    static let textMuted = Color(red: 0x93 / 255.0, green: 0xc5 / 255.0, blue: 0xfd / 255.0)

    // .tv-btn: bg-gradient-to-b from-amber-400 to-amber-600, text #3c2a15
    static let btnTop = Color(red: 0xfb / 255.0, green: 0xbf / 255.0, blue: 0x24 / 255.0)
    static let btnBottom = Color(red: 0xd9 / 255.0, green: 0x77 / 255.0, blue: 0x06 / 255.0)
    static let btnText = Color(red: 0x3c / 255.0, green: 0x2a / 255.0, blue: 0x15 / 255.0)

    // Semantic green/red used throughout (canAfford checks, requirements met, etc.)
    static let good = Color(red: 0x4a / 255.0, green: 0xde / 255.0, blue: 0x80 / 255.0)
    static let bad = Color(red: 0xf8 / 255.0, green: 0x71 / 255.0, blue: 0x71 / 255.0)

    static func configureGlobalAppearance() {
        let navy = UIColor(background)
        let panel = UIColor(panelTop)
        let amberUI = UIColor(amber)

        let navBar = UINavigationBarAppearance()
        navBar.configureWithOpaqueBackground()
        navBar.backgroundColor = navy
        navBar.titleTextAttributes = [.foregroundColor: amberUI]
        navBar.largeTitleTextAttributes = [.foregroundColor: amberUI]
        navBar.shadowColor = UIColor(panelBorder)
        let barButtonAppearance = UIBarButtonItemAppearance()
        barButtonAppearance.normal.titleTextAttributes = [.foregroundColor: amberUI]
        navBar.buttonAppearance = barButtonAppearance
        navBar.doneButtonAppearance = barButtonAppearance
        UINavigationBar.appearance().standardAppearance = navBar
        UINavigationBar.appearance().scrollEdgeAppearance = navBar
        UINavigationBar.appearance().compactAppearance = navBar
        UINavigationBar.appearance().tintColor = amberUI

        UITableView.appearance().backgroundColor = navy
        UITableViewCell.appearance().backgroundColor = panel
        UITableView.appearance().separatorColor = UIColor(panelBorder)

        UIToolbar.appearance().barTintColor = navy
    }
}

/// Mirrors `.tv-panel` — a rounded, bordered panel with the same navy gradient fill, used for
/// summary/header cards (village resource strip, hero stats, alliance header, …) that sit
/// outside a List.
struct GamePanelModifier: ViewModifier {
    var padding: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                LinearGradient(colors: [GameTheme.panelTop, GameTheme.panelBottom], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(GameTheme.panelBorder, lineWidth: 1))
    }
}

extension View {
    func gamePanel(padding: CGFloat = 12) -> some View {
        modifier(GamePanelModifier(padding: padding))
    }

    /// For the handful of screens whose top-level container is a ScrollView/VStack rather than
    /// a List (UITableView appearance above doesn't reach those) — explicit navy background.
    func gameScreenBackground() -> some View {
        background(GameTheme.background.ignoresSafeArea())
    }

    /// "убрать везде черный бэкграунд, везде должен быть одинаковый" — a `List` (especially
    /// `.insetGrouped`, UICollectionView-backed since iOS 16) paints its OWN opaque background
    /// underneath every row, which `configureGlobalAppearance()`'s `UITableView.appearance()`/
    /// `UITableViewCell.appearance()` proxies (above) don't reliably reach on that newer
    /// backing store — it fell back to system `.systemGroupedBackground`, which reads as plain
    /// black in dark mode (this app forces `.preferredColorScheme(.dark)`), instead of the
    /// game's actual navy. `.scrollContentBackground(.hidden)` turns the List's own background
    /// off so the explicit navy `.background()` underneath it (gameScreenBackground) can show
    /// through — apply this to every List-rooted screen instead of relying on the appearance
    /// proxies alone.
    func gameListBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .gameScreenBackground()
    }

    /// "часть скрыта под баром / так же скрывается под хедером" — every screen pushed inside
    /// MainTabView's NavigationStack sits between two pieces of CUSTOM chrome (GameHeaderBar via
    /// `.safeAreaInset(edge: .top)`, the bottom dock via `.safeAreaInset(edge: .bottom)`), not
    /// the system's own. Left alone, `.navigationTitle(...)` still makes NavigationStack render
    /// its OWN native UINavigationBar too — a second bar stacking with/overlapping GameHeaderBar
    /// (reported as garbled/doubled title text), and the extra unaccounted-for bar height also
    /// throws off how much space that screen's own List/ScrollView thinks it has for the bottom
    /// dock, so the last row(s) render clipped behind it. Hiding the native bar is the same fix
    /// VillageMapView/WorldMapView/FieldsMapView already apply individually (their own
    /// `.toolbar(.hidden, for: .navigationBar)`) — this is the same call, just reusable so every
    /// OTHER screen (Shop, Messages, Reports, …) gets it too instead of only the three maps.
    func gameNavBarHidden() -> some View {
        toolbar(.hidden, for: .navigationBar)
    }

    /// "Мага зин" — the per-screen ScreenTitleBar (see its own doc comment) used to be attached
    /// via `.safeAreaInset(edge: .top)`, same mechanism GameHeaderBar uses one level up in
    /// MainTabView. That's TWO independent `.safeAreaInset(edge: .top)` reservations stacked
    /// across a NavigationStack boundary — GameHeaderBar's, applied OUTSIDE the NavigationStack
    /// in MainTabView, and each screen's own ScreenTitleBar inset, applied INSIDE content pushed
    /// by that same NavigationStack (whose native bar is separately hidden via
    /// `gameNavBarHidden()`). In practice the two didn't reliably stack: ScreenTitleBar rendered
    /// overlapping GameHeaderBar's own space instead of directly below it (reported again after
    /// three previous rounds already re-verified GameHeaderBar's own reservation was correct —
    /// the bug was specifically in this SECOND, nested inset never being given its own distinct
    /// slot). Plain `VStack` composition has no such ambiguity — the title bar and the content
    /// below it are just two ordinary sibling views with deterministic sizes, nothing tries to
    /// merge two safe-area reservations through a hidden-nav-bar NavigationStack. `.refreshable`/
    /// `.task` chained after this (as every call site already does) still reaches the List/
    /// ScrollView inside `content` — those propagate via the environment, not a direct-child
    /// requirement, the same way they already worked when chained after `.safeAreaInset` before.
    func withScreenTitle<Title: View>(@ViewBuilder title: () -> Title) -> some View {
        // "основной экран должен быть в зеленой зоне" — without an explicit
        // `.frame(maxWidth: .infinity, maxHeight: .infinity)` here, this VStack only asks for
        // its IDEAL size (title's fixed height + however tall the List wants to be showing every
        // row at once, since a bare VStack doesn't force a scrollable child to clip to a bounded
        // height the way `.safeAreaInset` used to). Whatever presented this VStack (the
        // NavigationStack pushing it, with its native bar hidden) then had an oversized view to
        // fit into a bounded screen rect however it saw fit — observed as the title bar and the
        // first several list rows being cropped away entirely, as if the content had scrolled or
        // been centered inside its own oversized bounds, with no way to scroll back up to see
        // them. Forcing this VStack to actually fill (not just fit) the space it's given closes
        // that gap — the List inside `self` then gets a real bounded height to scroll within,
        // same as it always correctly did before this VStack refactor.
        VStack(spacing: 0) {
            title()
            self
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Mirrors `.tv-btn` — the amber gradient primary action button used everywhere on the web
/// (upgrade, send, buy, confirm, …).
struct GamePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [GameTheme.btnTop, GameTheme.btnBottom], startPoint: .top, endPoint: .bottom)
            )
            .foregroundStyle(GameTheme.btnText)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Mirrors `.tv-btn-secondary` — the outlined blue button used for secondary/instant-finish
/// actions.
struct GameSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .foregroundStyle(GameTheme.textSecondary)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(GameTheme.textMuted.opacity(0.5), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == GamePrimaryButtonStyle {
    static var gamePrimary: GamePrimaryButtonStyle { GamePrimaryButtonStyle() }
}

extension ButtonStyle where Self == GameSecondaryButtonStyle {
    static var gameSecondary: GameSecondaryButtonStyle { GameSecondaryButtonStyle() }
}

/// A rectangle with all four corners cut off at 45°, i.e. an elongated octagon — the frame
/// shape used throughout the reference header art the user supplied (the village nameplate,
/// the resource/currency badges): navy fill + gold border, corners sliced instead of rounded.
/// `cut` is clamped to half the shorter side, so it degrades gracefully on very small/thin
/// frames instead of self-intersecting.
struct CutCornerShape: Shape {
    var cut: CGFloat

    func path(in rect: CGRect) -> Path {
        let c = min(cut, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + c, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
        path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + c))
        path.closeSubpath()
        return path
    }
}

/// Navy-fill + gold-border cut-corner badge — the reusable frame for the header's nameplate and
/// currency/action slots (see CutCornerShape above). This is a native stand-in for the user's
/// own reference art; the icons placed inside it (emoji today) are meant to be swapped for the
/// matching bespoke PNGs later without touching this frame.
///
/// The resource badges (wood/clay/iron/crop) no longer use this modifier — they draw a real
/// `bg_res` image background instead (see GameHeaderBar.resourceBadge) once that navy-plate-
/// disappearing-into-the-navy-header problem ("на веб версии нет подложки") was solved with
/// bespoke art carrying its own baked-in gold border, rather than the louder flat amber fill
/// this modifier used to take via a `fill:` override.
struct GameOctagonBadgeModifier: ViewModifier {
    var cut: CGFloat = 8
    var fill: [Color] = [GameTheme.panelTop, GameTheme.panelBottom]

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(colors: fill, startPoint: .top, endPoint: .bottom)
                    .clipShape(CutCornerShape(cut: cut))
            )
            .overlay(
                CutCornerShape(cut: cut)
                    .stroke(LinearGradient(colors: [GameTheme.amberLight, GameTheme.btnBottom], startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
            )
    }
}

extension View {
    func gameOctagonBadge(cut: CGFloat = 8, fill: [Color] = [GameTheme.panelTop, GameTheme.panelBottom]) -> some View {
        modifier(GameOctagonBadgeModifier(cut: cut, fill: fill))
    }
}

/// Parses a "#rrggbb" (or "#rgb") hex string — the format Api\AuthController::avatarPayload()
/// sends preset avatar colors in (see config/avatars.php). Falls back to GameTheme.panelTop on
/// anything malformed, so a bad/future color string never crashes the header, just looks a
/// little duller.
extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else {
            self = GameTheme.panelTop
            return
        }
        self = Color(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }
}
