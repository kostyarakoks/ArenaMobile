import SwiftUI

/// Loading screen shown while AuthSession.restoreSession() checks a saved token — see
/// RootView.swift. Uses the wordmark (Logo.imageset / logo.png) rather than the app icon crest,
/// same as a typical game splash.
struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 10 / 255, green: 23 / 255, blue: 48 / 255), Color(red: 19 / 255, green: 42 / 255, blue: 77 / 255)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 280)
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 6)

                ProgressView()
                    .tint(.white)
            }
            .padding(.horizontal, 32)

            // See AppVersion.swift's own doc comment for why this shows here and in "Ещё".
            VStack {
                Spacer()
                Text(AppVersion.displayString)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 16)
            }
        }
    }
}

#Preview {
    SplashView()
}
