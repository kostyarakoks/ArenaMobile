import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: AuthSession

    // Никнейм убран — сервер сам сгенерирует дефолтное имя (Api\AuthController::register).
    @State private var tribe = "roman" // Значение по умолчанию

    // ИЗМЕНЕНО: добавлено третье поле `asset` — точное имя картинки в Assets.xcassets.
    // `key` остаётся нижним регистром, потому что именно его сервер ждёт в поле `tribe`
    // (см. Api\AuthController::register -> Rule::in(config('game.tribes'))).
    private let tribes: [(key: String, label: String, asset: String)] = [
        ("roman", "Римляне", "roman"),
        ("teuton", "Тевтоны", "Teuton"),
        ("gaul", "Галлы", "Gaul"),
    ]

    var body: some View {
        ZStack {
            // 1. Фоновое изображение (замок, река, каменная платформа).
            Image("LoginBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            // 2. UI поверх фона
            VStack(spacing: 0) {
                // Логотип
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 240)
                    .padding(.top, 60)

                Spacer() // Сдвигает персонажа вниз, к платформе на фоне

                // Слайдер персонажей.
                TabView(selection: $tribe) {
                    ForEach(tribes, id: \.key) { option in
                        // ИЗМЕНЕНО: используем option.asset вместо option.key
                        Image(option.asset) 
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 350)
                            .offset(y: 10) // Подстройте, чтобы ноги стояли на платформе
                            .tag(option.key)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 300)

                Spacer() // Прижимает кнопку к низу

                // Кнопка "Играть"
                Button {
                    // Отправляем на сервер ключ (roman/teuton/gaul), а не имя ассета
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
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthSession())
}