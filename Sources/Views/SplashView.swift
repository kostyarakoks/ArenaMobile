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
/// Собран из трёх присланных спрайтов (нарезаны из одного PNG по прозрачным
/// промежуткам между слоями — сама рамка, синяя подложка, золотое
/// заполнение): "ProgressBarFrame", "ProgressBarTrack", "ProgressBarFill".
/// Раньше эти три имени ссылались в никуда (картинок не было в
/// Assets.xcassets, `Image(...)` тихо рисовал пустоту) — сейчас файлы на
/// месте, и вместо временной замены на `Capsule()` здесь снова настоящие
/// картинки.
///
/// Рамка ("ProgressBarFrame") — гораздо более "толстый" декоративный
/// элемент, чем трек/заполнение внутри неё: между двумя её тонкими синими
/// направляющими линиями (замерено по пиксельным координатам в исходном
/// PNG — 2130×302) есть полость, где и должны лежать трек с заполнением,
/// а не просто "по центру рамки". `cavity…Fraction` ниже — координаты этой
/// полости в долях от размера рамки, так они остаются верными на любой
/// ширине экрана (рамка масштабируется по своим пропорциям, полость вместе
/// с ней).
struct OrnateProgressBar: View {
    let progress: Double

    /// Полость между направляющими линиями рамки: 23.2%–69.5% высоты рамки,
    /// с отступами 11.7% слева/справа (где рамку огибают декоративные
    /// наконечники).
    private let cavityTopFraction: CGFloat = 0.232
    private let cavityBottomFraction: CGFloat = 0.695
    private let cavityInsetFraction: CGFloat = 0.117

    var body: some View {
        Image("ProgressBarFrame")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                GeometryReader { geo in
                    let cavityHeight = geo.size.height * (cavityBottomFraction - cavityTopFraction)
                    let cavityY = geo.size.height * (cavityTopFraction + cavityBottomFraction) / 2
                    let inset = geo.size.width * cavityInsetFraction
                    let cavityWidth = max(0, geo.size.width - inset * 2)
                    let fillWidth = max(0, cavityWidth * progress)

                    ZStack(alignment: .leading) {
                        Image("ProgressBarTrack")
                            .resizable()
                            .frame(width: cavityWidth, height: cavityHeight)

                        // Растянута на всю ширину трека (чтобы скруглённые концы не
                        // сплющивались при малом progress), а видна только левая часть —
                        // через .mask, а не через обрезку ширины самой картинки.
                        Image("ProgressBarFill")
                            .resizable()
                            .frame(width: cavityWidth, height: cavityHeight)
                            .mask(alignment: .leading) {
                                Rectangle().frame(width: fillWidth)
                            }
                    }
                    .position(x: geo.size.width / 2, y: cavityY)
                }
            }
            .allowsHitTesting(false)
    }
}

#Preview {
    SplashView()
}