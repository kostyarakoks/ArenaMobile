import SwiftUI

/// Top-level switch, driven entirely by AuthSession.phase: SplashView while a saved token is
/// being checked, LoginView once we know there's no (valid) session, MainTabView once signed
/// in. See ArenaMobileApp.swift for where AuthSession itself is created and restoreSession() is
/// kicked off.
struct RootView: View {
    @EnvironmentObject private var session: AuthSession

    init() {
        // Once per launch: dark-navy/amber UINavigationBar + UITableView appearance, matching
        // the web app's palette (see GameTheme.swift) — reaches List-based screens and
        // navigation bars app-wide without touching each screen individually.
        GameTheme.configureGlobalAppearance()
    }

    var body: some View {
        Group {
            switch session.phase {
case .loading:
    SplashView()
case .signedOut:
    LoginView()
case .signedIn:
    MainTabView()
}
        }
        // The whole app is built around the dark-navy/amber palette (see GameTheme.swift), not
        // a light/dark adaptive one — forcing dark keeps every default SwiftUI `.primary`/
        // `.secondary` text (and system control colors) legible on that background everywhere,
        // not just in the screens that set colors explicitly.
        .preferredColorScheme(.dark)
        .tint(GameTheme.amber)
    }
}

#Preview {
    RootView()
        .environmentObject(AuthSession())
}
