import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: AuthSession
    @StateObject private var gameCenter = GameCenterAuth.shared

    @State private var tribe = "roman"

    private let tribes: [(key: String, label: String, asset: String)] = [
        ("roman",  "Римляне", "Roman"),
        ("teuton", "Тевтоны", "Teuton"),
        ("gaul",   "Галлы",   "Gaul"),
    ]

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
                    .frame(maxWidth: 240)
                    .padding(.top, 40)

                // Бейдж статуса Game Center
                gameCenterBadge
                    .padding(.top, 16)

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

                // Кнопка "Играть" — активна только когда GC подключён.
                Button {
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
                .background(canPlay ? Color(red: 1, green: 0.84, blue: 0.47) : Color.white.opacity(0.25))
                .foregroundStyle(canPlay ? .black : .white.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(!canPlay || session.isSubmitting)

                // Кнопка "Повторить" — только если подключение провалилось.
                if case .failed = gameCenter.status {
                    Button {
                        Task { try? await gameCenter.authenticate() }
                    } label: {
                        Text("Повторить подключение к Game Center")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 10)
                }

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
        // Пробуем подключиться к Game Center сразу при показе экрана.
        // Если уже подключён (кэш) — authenticate() вернёт мгновенно.
        .task {
            try? await gameCenter.authenticate()
        }
    }

    private var canPlay: Bool {
        gameCenter.status.isConnected
    }

    @ViewBuilder
    private var gameCenterBadge: some View {
        let (icon, text, color) = badgeContent
        HStack(spacing: 6) {
            if case .connecting = gameCenter.status {
                ProgressView().tint(.white).scaleEffect(0.8)
            } else {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.55))
        .clipShape(Capsule())
    }

    private var badgeContent: (icon: String, text: String, color: Color) {
        switch gameCenter.status {
        case .unknown:
            return ("circle.dashed", "Game Center: ожидание…", .gray)
        case .connecting:
            return ("arrow.triangle.2.circlepath", "Подключение к Game Center…", .white)
        case .connected(_, let name):
            return ("checkmark.circle.fill", "Game Center подключён: \(name)", .green)
        case .failed(let message):
            return ("xmark.octagon.fill", message, .red)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthSession())
}