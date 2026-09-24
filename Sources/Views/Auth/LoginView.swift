import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var nickname = ""
    @State private var tribe = "roman"

    private let tribes: [(key: String, label: String, asset: String)] = [
        ("roman",  "Римляне", "Roman"),
        ("teuton", "Тевтоны", "Teuton"),
        ("gaul",   "Галлы",   "Gaul"),
    ]

    private var canPlay: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                    .padding(.top, 40)

                // Поле никнейма
                TextField("Никнейм", text: $nickname)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .padding(.top, 24)
                    .padding(.horizontal, 28)

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

                Spacer()

                // Кнопка «Играть»
                Button {
                    Task {
                        await session.register(
                            name: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                            tribe: tribe
                        )
                    }
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