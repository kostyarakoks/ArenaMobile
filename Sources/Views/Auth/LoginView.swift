import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: AuthSession

    // Никнейм убран — сервер сам сгенерирует дефолтное имя (Api\AuthController::register).
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

            VStack(spacing: 0) {
                // Логотип
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 240)
                    .padding(.top, 60) // Отступ от верхнего края (Safe Area)

                Spacer() // ОТСТУП: сдвигает персонажа и подиум вниз

                // Блок "подиум + персонаж"
                ZStack(alignment: .bottom) {
                    // Подиум (один на всех). Убедитесь, что картинка добавлена в
                    // Assets.xcassets как "Podium" (PNG с прозрачным фоном).
                    Image("Podium")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 300)
                        // ИЗМЕНЕНО: подиум сдвинут ниже (было 20, стало 40)
                        .offset(y: 40)

                    // Слайдер персонажей. indexDisplayMode: .never — убраны точки-индикаторы.
                    TabView(selection: $tribe) {
                        ForEach(tribes, id: \.key) { option in
                            Image(option.key)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 260) // Увеличенный размер персонажа
                                // ИЗМЕНЕНО: персонаж опущен, чтобы встать на сдвинутый подиум
                                .offset(y: 0)
                                .tag(option.key)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: 300) // Высота слайдера
                }
                .frame(height: 320) // Общая высота блока с подиумом и персонажем

                Spacer() // ОТСТУП: прижимает кнопку "Играть" к самому низу экрана

                // Кнопка "Играть"
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
                .background(Color(red: 1, green: 0.84, blue: 0.47))
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(session.isSubmitting)

                if let error = session.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20) // Отступ от нижнего края (Safe Area / Home Indicator)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthSession())
}