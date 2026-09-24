import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: AuthSession

    // Instant-play fields
    @State private var nickname = ""
    @State private var tribe = "roman" // Значение по умолчанию

    // Existing-account fallback, collapsed by default
    @State private var showExistingAccount = false
    @State private var email = ""
    @State private var password = ""

    private let tribes: [(key: String, label: String)] = [
        ("roman", "Римляне"),
        ("teuton", "Тевтоны"),
        ("gaul", "Галлы"),
    ]

    private var canPlay: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var canSignIn: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 10 / 255, green: 23 / 255, blue: 48 / 255), Color(red: 19 / 255, green: 42 / 255, blue: 77 / 255)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 240)
                        .padding(.top, 40)

                    VStack(spacing: 14) {
                        field(title: "Никнейм", text: $nickname, keyboard: .default, isSecure: false)

                        // ЗАМЕНА: Слайдер выбора племени
                        TabView(selection: $tribe) {
                            ForEach(tribes, id: \.key) { option in
                                VStack(spacing: 8) {
                                    // Картинка племени (убедитесь, что имена файлов совпадают с ключами)
                                    Image(option.key) 
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 180)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                                    
                                    // Название племени под картинкой
                                    Text(option.label)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                                .tag(option.key) // Привязываем тег к значению tribe
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                        .frame(height: 240) // Высота слайдера
                        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                    }

                    if let error = session.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await session.register(name: nickname.trimmingCharacters(in: .whitespaces), tribe: tribe) }
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
                    .background(canPlay ? Color(red: 1, green: 0.84, blue: 0.47) : Color.white.opacity(0.2))
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(!canPlay || session.isSubmitting)

                    DisclosureGroup(isExpanded: $showExistingAccount) {
                        VStack(spacing: 14) {
                            field(title: "Email", text: $email, keyboard: .emailAddress, isSecure: false)
                            field(title: "Пароль", text: $password, keyboard: .default, isSecure: true)

                            Button {
                                Task { await session.login(email: email, password: password) }
                            } label: {
                                HStack {
                                    if session.isSubmitting {
                                        ProgressView().tint(.white)
                                    }
                                    Text("Войти").fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                            .background(Color.white.opacity(canSignIn ? 0.18 : 0.08))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .disabled(!canSignIn || session.isSubmitting)
                        }
                        .padding(.top, 10)
                    } label: {
                        Text("Уже есть аккаунт? Войти")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .tint(.white)
                    .padding(12)
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }

    private func field(title: String, text: Binding<String>, keyboard: UIKeyboardType, isSecure: Bool) -> some View {
        Group {
            if isSecure {
                SecureField(title, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                TextField(title, text: text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding(14)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .foregroundStyle(.white)
        .tint(.white)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthSession())
}