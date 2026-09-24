import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: AuthSession

    // Никнейм убран — сервер сам сгенерирует "Игрок id{N}".
    // Авторизация — Game Center (см. AuthSession.register).
    @State private var tribe = "roman"

    private let tribes: [(key: String, label: String, asset: String)] = [
        ("roman",  "Римляне", "Roman"),
        ("teuton", "Тевтоны", "Teuton"),
        ("gaul",   "Галлы",   "Gaul"),
    ]

    var body: some View {
        ZStack {
            // Фон (замок, река, каменная платформа).
            Image("LoginBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 240)
                    .padding(.top, 60)

                Spacer()

                TabView(selection: $tribe) {
                    ForEach(tribes, id: \.key) { option in
                        Image(option.asset)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 390)
                            .offset(y: -20)
                            .tag(option.key)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 450)

                Spacer()

                Button {
                    // Главное отличие: теперь НЕ передаём name.
                    // AuthSession сам:
                    //   1) аутентифицируется в Game Center,
                    //   2) отправит teamPlayerID на сервер,
                    //   3) сервер вернёт токен существующего аккаунта
                    //      либо создаст новый.
                    Task { await session.register(tribe: tribe) }
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