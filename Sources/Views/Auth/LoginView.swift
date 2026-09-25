import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: AuthSession

    // Первый слайд — роман (первый элемент tribes ниже), как и просили.
    @State private var tribe = "roman"

    // "когда первый слайд с лева и справа вылазят другие племена / когда перелистывется на
    // другой слайд они убираются и показываются в следующий раз на среднем слайде через 10
    // секунд" — на КАЖДОМ слайде (не только первом) два других племени «выглядывают» из-за
    // левого/правого края экрана, но не сразу: только если игрок 10 секунд не листает. Свайп на
    // другой слайд сразу прячет выглядывающих (без анимации — резко, как и должно быть при
    // "убираются"), и 10-секундный таймер запускается заново для нового слайда.
    @State private var showPeekers = false
    @State private var peekTask: Task<Void, Never>?

    private let tribes: [(key: String, label: String, asset: String)] = [
        ("roman",  "Римляне", "Roman"),
        ("teuton", "Тевтоны", "Teuton"),
        ("gaul",   "Галлы",   "Gaul"),
    ]

    private var canPlay: Bool {
        !session.isSubmitting
    }

    private var currentIndex: Int { tribes.firstIndex(where: { $0.key == tribe }) ?? 0 }

    // Круговой порядок (roman → teuton → gaul → roman): на любом слайде ровно одно племя слева
    // и одно справа, включая крайние — на roman слева выглядывает gaul (по кругу), а не пустота.
    private var leftPeekAsset: String {
        tribes[(currentIndex - 1 + tribes.count) % tribes.count].asset
    }
    private var rightPeekAsset: String {
        tribes[(currentIndex + 1) % tribes.count].asset
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
                .zIndex(1) // выбранное племя всегда поверх выглядывающих слева/справа
                .overlay(alignment: .leading) {
                    if showPeekers {
                        peekCharacter(asset: leftPeekAsset)
                            .offset(x: -60)
                            .transition(.opacity)
                    }
                }
                .overlay(alignment: .trailing) {
                    if showPeekers {
                        peekCharacter(asset: rightPeekAsset)
                            .offset(x: 60)
                            .transition(.opacity)
                    }
                }

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
            schedulePeekReveal()
        }
        .onChange(of: tribe) { _ in
            hidePeekersAndReschedule()
        }
        .onDisappear {
            peekTask?.cancel()
        }
    }

    // Персонаж, «выглядывающий» из-за края экрана — уменьшенная и притемнённая копия того же
    // самого арта племени, что уже используется в самом слайдере (Roman/Teuton/Gaul.imageset),
    // сдвинутая за пределы видимой области так, чтобы наружу торчала примерно половина.
    private func peekCharacter(asset: String) -> some View {
        Image(asset)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 260)
            .opacity(0.8)
            .shadow(color: .black.opacity(0.35), radius: 6)
            .allowsHitTesting(false)
    }

    // "показываются в следующий раз на среднем слайде через 10 секунд" — 10 секунд простоя на
    // текущем (уже «среднем») слайде, и только потом плавно появляются оба соседа.
    private func schedulePeekReveal() {
        peekTask?.cancel()
        peekTask = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                showPeekers = true
            }
        }
    }

    // "когда перелистывется на другой слайд они убираются" — резко, без анимации, сразу при
    // свайпе, и таймер на 10 секунд запускается заново уже для нового слайда.
    private func hidePeekersAndReschedule() {
        showPeekers = false
        schedulePeekReveal()
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthSession())
}