import SwiftUI

/// Loading screen shown while AuthSession.restoreSession() checks a saved token — see
/// RootView.swift. Uses the wordmark (Logo.imageset / logo.png) rather than the app icon crest,
/// same as a typical game splash.
struct SplashView: View {
    var body: some View {
        ZStack {
            // 1. Фоновое изображение (пейзаж)
            Image("SplashBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            // 2. Персонаж (гном) в левом нижнем углу
            Image("DwarfCharacter")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .ignoresSafeArea(edges: .bottom) // Прижимаем к самому низу экрана

            // 3. Логотип сверху по центру
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 300)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 60) // Отступ от верхнего края (можно подстроить под Safe Area)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

            // 4. Индикатор загрузки (оставляем, так как это экран ожидания)
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 40) // Отступ снизу, чтобы не перекрывать элементы
        }
    }
}

#Preview {
    SplashView()
}