import SwiftUI

/// First screen a signed-out player sees (see RootView.swift). Primary flow is "instant play" —
/// type a nickname, pick a tribe, tap "Играть" — exactly like a normal mobile game's guest
/// account, with no email/password ever asked (Api\AuthController::register generates both
/// server-side; the bearer token this returns is the account's only credential going forward,
/// stored in the Keychain — see AuthSession.swift). Signing in with an existing web-app account
/// is still possible, just tucked behind a small "Уже есть аккаунт?" disclosure instead of being
/// the front door, per the explicit request to stop making new players deal with login/password.
struct LoginView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var serverURL: String = UserDefaults.standard.string(forKey: APIClient.baseURLDefaultsKey) ?? ""
    @State private var showServerField = false

    // Instant-play fields
    @State private var nickname = ""
    @State private var tribe = "roman"

    // Existing-account fallback, collapsed by default
    @State private var showExistingAccount = false
    @State private var email = ""
    @State private var password = ""

    private let tribes: [(key: String, label: String)] = [
        ("roman", "Римляне"),
        ("teuton", "Тевтоны"),
        ("gaul", "Галлы"),
    ]

    private var serverIsValid: Bool {
        URL(string: serverURL)?.scheme?.hasPrefix("http") == true
    }

    private var canPlay: Bool {
        !nickname.trimmingCharacters(in: .whitespaces).isEmpty && serverIsValid
    }

    private var canSignIn: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && serverIsValid
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

                        // Tribe picker — same 3 choices/labels as the web app's own registration
                        // form (Pages/Auth/Register.vue), just rendered as a row of buttons
                        // instead of radio inputs.
                        HStack(spacing: 8) {
                            ForEach(tribes, id: \.key) { option in
                                Button {
                                    tribe = option.key
                                } label: {
                                    Text(option.label)
                                        .font(.footnote.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                }
                                .background(tribe == option.key ? Color(red: 1, green: 0.84, blue: 0.47) : Color.white.opacity(0.1))
                                .foregroundStyle(tribe == option.key ? .black : .white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
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

                    // Existing (web-registered) account — collapsed by default so it never reads
                    // as "step 1" for a brand-new player, but still reachable for anyone who
                    // already has an account and just wants this device signed into it.
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
        .onAppear {
            if serverURL.isEmpty { showServerField = true }
        }
    }

    private func field(title: String, text: Binding<String>, keyboard: UIKeyboardType, isSecure: Bool) -> some View {
        Group {
            if isSecure {
                SecureField(title, text: text)
                    // SwiftUI's SecureField, unlike UIKit's secure UITextField, does NOT disable
                    // autocapitalization on its own — left at the default `.sentences`, it
                    // silently capitalizes the first character typed, so a correct password gets
                    // submitted wrong and the server (correctly) rejects it. That's the exact
                    // "сейчас не пускает на ios по паролю" bug report: the password on screen
                    // looked right (SecureField hides it anyway) but what actually got sent
                    // wasn't what was typed. Explicit `.never` here matches what the email field
                    // below already had.
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
