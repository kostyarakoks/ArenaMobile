import SwiftUI

/// The "Арена" screen — Api\ArenaController (travianz-laravel), same ArenaService the web
/// Arena/Index.vue page uses: your squad's power vs. a random opponent, one tap to fight.
struct ArenaView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var detail: ArenaDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var lastResult: ArenaFightResult?

    var body: some View {
        content
            .gameScreenBackground()
            .safeAreaInset(edge: .top, spacing: 0) { ScreenTitleBar("Арена") }
            .task {
                guard detail == nil else { return }
                await load()
            }
            .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && detail == nil {
            ProgressView("Загрузка арены…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить арену").font(.headline)
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Повторить") { Task { await load() } }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let detail {
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Text("🏆 Очки арены").font(.headline).foregroundStyle(GameTheme.amber)
                        Spacer()
                        Text("\(detail.arenaPoints)").font(.headline.monospacedDigit()).foregroundStyle(GameTheme.textPrimary)
                    }

                    HStack(spacing: 16) {
                        VStack {
                            Text("Ваш отряд").font(.caption).foregroundStyle(GameTheme.textSecondary)
                            Text("\(detail.myPower)").font(.title.bold()).foregroundStyle(GameTheme.textPrimary)
                        }
                        Text("VS").font(.title3.bold()).foregroundStyle(GameTheme.textSecondary)
                        VStack {
                            Text(detail.opponent.label).font(.caption).foregroundStyle(GameTheme.textSecondary).multilineTextAlignment(.center)
                            Text("\(detail.opponent.power)").font(.title.bold()).foregroundStyle(GameTheme.textPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .gamePanel()

                    Button {
                        Task { await fight() }
                    } label: {
                        Text("В бой!")
                    }
                    .buttonStyle(.gamePrimary)
                    .disabled(isBusy || detail.myPower <= 0)

                    if detail.myPower <= 0 {
                        Text("Соберите отряд полководцев, прежде чем выходить на арену.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    if let lastResult {
                        VStack(spacing: 6) {
                            Text(lastResult.won ? "Победа! 🎉" : "Поражение").font(.headline)
                                .foregroundStyle(lastResult.won ? GameTheme.good : GameTheme.bad)
                            Text("\(lastResult.myPower) vs \(lastResult.opponentPower) — \(lastResult.opponentLabel)")
                                .font(.footnote).foregroundStyle(GameTheme.textSecondary)
                            Text("\(lastResult.pointsDelta >= 0 ? "+" : "")\(lastResult.pointsDelta) очков")
                                .font(.footnote.bold())
                                .foregroundStyle(GameTheme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .gamePanel()
                    }
                }
                .padding(16)
            }
            .disabled(isBusy)
            .gameScreenBackground()
        } else {
            Color.clear
        }
    }

    private func load() async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            detail = try await APIClient.shared.fetchArena(token: token)
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
        isLoading = false
    }

    private func fight() async {
        guard let token = session.bearerToken else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            lastResult = try await APIClient.shared.fightArena(token: token)
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }
}
