import SwiftUI

/// Signs in against the real account on your TravianZ server via POST /api/login (see
/// AuthController.php + AuthSession.swift). Since every TravianZ install lives at its own
/// domain, there's no sensible built-in server address — the first thing a fresh install of
/// this app needs is that URL, entered once below (saved in UserDefaults, so it only needs to
/// be typed again after reinstalling the app or switching servers).
struct LoginView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var serverURL: String = UserDefaults.standard.string(forKey: APIClient.baseURLDefaultsKey) ?? ""
    @State private var email = ""
    @State private var password = ""
    @State private var showServerField = false

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && URL(string: serverURL)?.scheme?.hasPrefix("http") == true
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
                        field(title: "Email", text: $email, keyboard: .emailAddress, isSecure: false)
                        field(title: "Пароль", text: $password, keyboard: .default, isSecure: true)
                    }

                    DisclosureGroup(isExpanded: $showServerField) {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("https://ваш-сервер.example.com", text: $serverURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .padding(12)
                                .background(.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.white)
                                .onChange(of: serverURL) { newValue in
                                    // Single-parameter onChange, not the two-parameter
                                    // (oldValue, newValue) overload — that one needs iOS 17,
                                    // and this project's deployment target is iOS 16.
                                    UserDefaults.standard.set(newValue, forKey: APIClient.baseURLDefaultsKey)
                                }
                            Text("Адрес вашего сайта с игрой, без /login в конце.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.top, 8)
                    } label: {
                        Label(serverURL.isEmpty ? "Указать адрес сервера" : serverURL, systemImage: "server.rack")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .tint(.white)
                    .padding(12)
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    if let error = session.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await session.login(email: email, password: password) }
                    } label: {
                        HStack {
                            if session.isSubmitting {
                                ProgressView().tint(.black)
                            }
                            Text("Войти").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .background(canSubmit ? Color(red: 1, green: 0.84, blue: 0.47) : Color.white.opacity(0.2))
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(!canSubmit || session.isSubmitting)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            if serverURL.isEmpty { showServerField = true }
        }
    }

    private func field(title: String, text: Binding<String>, keyboard: UIKeyboardType, isSecure: Bool) -> some View {
        Group {
            if isSecure {
                SecureField(title, text: text)
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
