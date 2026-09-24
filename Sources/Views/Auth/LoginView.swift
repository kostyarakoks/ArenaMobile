import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var tribe = "roman"

    private let tribes: [(key: String, label: String, asset: String)] = [
        ("roman",  "Римляне", "Roman"),
        ("teuton", "Тевтоны", "Teuton"),
        ("gaul",   "Галлы",   "Gaul"),
    ]

    private var canPlay: Bool {
        !session.isSubmitting
    }

    var body: some View {
        ZStack {
            Image("LoginBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 220)
                    .padding(.top, 60)

                Spacer()

                // Слайдер племён
                TabView(selection: $tribe) {
                    ForEach(tribes, id: \.key) { option in
                        Image(option.asset)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 360)
                            .offset(y: -10)
                            .tag(option.key)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 400)

                // Название выбранного племени
                if let current = tribes.first(where: { $0.key == tribe }) {
                    Text(current.label)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.top, 4)
                }

                Spacer()

                // Кнопка «Играть»
                Button {
                    Task {
                        await session.register(tribe: tribe)
                    }
                } label: {
                    HStack(spacing: 8) {
                        if session.isSubmitting {
                            ProgressView().tint(.black)
                        }
                        Text(session.isSubmitting ? "Создание аккаунта…" : "Играть")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .background(canPlay ? Color(red: 1, green: 0.84, blue: 0.47) : Color.white.opacity(0.25))
                .foregroundStyle(canPlay ? .black : .white.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(!canPlay)

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
        .onAppear {
            // Сбрасываем isSubmitting/errorMessage, если они залипли
            // после прошлой неудачной попытки.
            session.resetTransientState()
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthSession())
}