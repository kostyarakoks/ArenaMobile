import SwiftUI

/// Top-level switch, driven entirely by AuthSession.phase: SplashView while a saved token is
/// being checked, LoginView once we know there's no (valid) session, MainTabView once signed
/// in. See ArenaMobileApp.swift for where AuthSession itself is created and restoreSession() is
/// kicked off.
struct RootView: View {
    @EnvironmentObject private var session: AuthSession

    var body: some View {
        switch session.phase {
        case .checkingStoredToken:
            SplashView()
        case .signedOut:
            LoginView()
        case .signedIn:
            MainTabView()
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AuthSession())
}
