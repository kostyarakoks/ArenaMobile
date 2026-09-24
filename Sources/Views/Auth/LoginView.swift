import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: AuthSession

    // Instant-play fields
    // Никнейм убран — сервер сам сгенерирует/примет дефолтное имя (Api\AuthController::register).
    // Остаётся только выбор племени через слайдер с картинками.
    @State private var tribe = "roman" // Значение по умолчанию

    private let tribes: [(key: String, label: String)] = [
        ("roman", "Римляне"),
        ("teuton", "Тевтоны"),
        ("gaul", "Галлы"),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 10 / 255, green: 23 / 255, blue: 48 / 255), Color(red: 19 / 255, green: 42 / 255, blue: 77 / 255)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    // Логотип — сдвинут вверх, чтобы дать место увеличенным персонажам.
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 240)
                        .padding(.top, 40)

                    // Блок "подиум + персонаж":
                    // ZStack(alignment: .bottom) прижимает оба слоя к низу своего фрейма,
                    // поэтому персонаж стоит ровно на подиуме, а TabView листается
                    // горизонтально поверх подиума.
                    ZStack(alignment: .bottom) {
                        // Подиум (один на всех). Убедитесь, что картинка добавлена в
                        // Assets.xcassets как "Podium" (PNG с прозрачным фоном).
                        Image("Podium")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 300)
                            .offset(y: 20) // Смещение вниз, чтобы ноги персонажа касались подиума

                        // Слайдер персонажей. indexDisplayMode: .never — убраны точки-индикаторы.
                        TabView(selection: $tribe) {
                            ForEach(tribes, id: \.key) { option in
                                Image(option.key)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 260) // Увеличенный размер персонажа
                                    .offset(y: -20) // Приподнят над подиумом
                                    .tag(option.key) // Привязка тега к значению tribe
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: 300) // Высота слайдера
                    }
                    .frame(height: 320) // Общая высота блока с подиумом и персонажем

                    // Кнопка "Играть". Никнейм убран — регистрируемся как "Игрок".
                    Button {
                        Task { await session.register(name: "Игрок", tribe: tribe) }
                    } label: {
                        HStack {
                            if session.isSubmitting {
                                ProgressView().tint(.black)
                            }
                            Text("Играть").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .background(Color(red: 1, green: 0.84, blue: 0.47)) // Всегда активна, поля для ввода нет
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(session.isSubmitting)

                    if let error = session.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthSession())
}