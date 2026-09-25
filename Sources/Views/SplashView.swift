import SwiftUI

/// Loading screen shown while AuthSession.restoreSession() checks a saved token — see
/// RootView.swift. Uses the wordmark (Logo.imageset / logo.png) rather than the app icon crest,
/// same as a typical game splash.
///
/// Композиция как на референсе:
///   • Фон — пейзаж с замком и горами ("SplashBackground").
///   • Скала/островок в левом нижнем углу ("Background23" — это тот кусок с камнями
///     и травой, на котором стоит гном).
///   • Персонаж-гном ("DwarfCharacter") стоит на этой скале.
///   • Логотип ("Logo") сверху по центру.
///   • Орнаментный прогресс-бар снизу по центру.
struct SplashView: View {
    @State private var progress: Double = 0

    var body: some View {
        ZStack {
            // 1. Фон — пейзаж (замок, горы, река). Растягивается на весь экран.
            Image("SplashBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            // 2. Скала (островок) — прижата к левому нижнему углу.
            //    Именно на ней стоит гном, поэтому рисуется ДО персонажа.
            Image("Background23")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 400, height: 259, alignment: .bottomLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: -30) // чуть вывести за левый край — как на референсе
                .ignoresSafeArea(edges: .bottom)

            // 3. Персонаж-гном — стоит на скале, прижат к левому нижнему углу.
            Image("DwarfCharacter")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 340)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: 8, y: -60) // поднимаем чуть выше, чтобы ноги были на скале
                .ignoresSafeArea(edges: .bottom)

            // 4. Логотип сверху по центру.
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 60)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)

            // 5. Прогресс-бар снизу.
            VStack {
                Spacer()
                OrnateProgressBar(progress: progress)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 60)
            }
        }
        .onAppear {
            // Анимированное заполнение от 0 до 100% за 2.5 секунды.
            // Реальный прогресс с сервера не приходит, поэтому имитируем
            // плавный рост — этого достаточно, чтобы игрок видел «жизнь».
            progress = 0
            withAnimation(.easeInOut(duration: 2.5)) {
                progress = 1.0
            }
        }
    }
}

/// Орнаментный прогресс-бар в стиле игры.
///
/// Собран из ТРЁХ отдельных спрайтов, которые вы прислали (на одной
/// картинке там несколько слоёв). Разрежьте её на три `.imageset`:
///
///   • "ProgressBarFrame" — верхний ornate-бордер (золотая рама с
///     узорами по краям и ромбиками посередине). Это самый высокий слой,
///     рисуется поверх всего.
///
///   • "ProgressBarTrack" — синяя полоска (фон-трек, на который
///     накладывается заполнение). С закруглениями по краям.
///
///   • "ProgressBarFill"  — золотая полоска (заполнение, растёт слева
///     направо в такт с `progress`).
///
/// Если у вас сейчас всё в одном файле — назовите его как угодно и
/// покажите — я подскажу, как нарезать его на три части в Figma/Preview.
///
/// Если ассетов пока нет вообще — замените три `Image(...)` на простые
/// `Capsule()` с градиентами, будет работать без картинок.
struct OrnateProgressBar: View {
    let progress: Double

    var body: some View {
        ZStack {
            // Слой 1: трек (синий). Отступы по бокам — чтобы орнамент
            // рамы не перекрывал края.
            Image("ProgressBarTrack")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 20)
                .clipShape(Capsule())
                .padding(.horizontal, 30)

            // Слой 2: золотое заполнение — растёт слева направо.
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Image("ProgressBarFill")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: max(0, (geo.size.width - 60) * progress), height: 20)
                        .clipShape(Capsule())
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 30)
            }
            .frame(height: 20)
            .allowsHitTesting(false)

            // Слой 3: орнаментная рама — рисуется поверх всего, растягивается
            // по ширине.
            Image("ProgressBarFrame")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
        }
        .frame(height: 44)
    }
}

#Preview {
    SplashView()
}