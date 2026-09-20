import Foundation

/// Reads the build's own version/build number straight from the app bundle — MARKETING_VERSION
/// and CURRENT_PROJECT_VERSION (project.yml) — instead of hardcoding it anywhere, so it's always
/// exactly whatever's actually running, including on a build whose version was bumped without
/// remembering to update some second copy of the string.
///
/// Shown per an explicit request: "добавить в приложение номер версии сборки при загрузки и при
/// открытие «еще»" — on SplashView (while the app is loading) and inside MainTabView's "Ещё"
/// sheet, so it's reachable both the moment the app opens and any time afterward without digging
/// through Settings.
enum AppVersion {
    /// "1.0.1" — CFBundleShortVersionString, the user-facing App Store "Version". Falls back to
    /// "?" only if Info.plist is somehow missing the key (shouldn't happen — XcodeGen always
    /// populates it from MARKETING_VERSION).
    static var marketing: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    /// "2" — CFBundleVersion, the build number that must strictly increase on every submitted
    /// build even within the same marketing version (see project.yml's own comment on it).
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    /// "v1.0.1 (2)" — the one string every call site actually wants to display.
    static var displayString: String {
        "v\(marketing) (\(build))"
    }
}
