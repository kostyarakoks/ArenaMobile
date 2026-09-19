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
            .navigationTitle("Арена")
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
                        Text("🏆 Очки арены").font(.headline)
                        Spacer()
                        Text("\(detail.arenaPoints)").font(.headline.monospacedDigit())
                    }

                    HStack(spacing: 16) {
                        VStack {
                            Text("Ваш отряд").font(.caption).foregroundStyle(.secondary)
                            Text("\(detail.myPower)").font(.title.bold())
                        }
                        Text("VS").font(.title3.bold()).foregroundStyle(.secondary)
                        VStack {
                            Text(detail.opponent.label).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            Text("\(detail.opponent.power)").font(.title.bold())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        Task { await fight() }
                    } label: {
                        Text("В бой!").font(.headline).frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy || detail.myPower <= 0)

                    if detail.myPower <= 0 {
                        Text("Соберите отряд полководцев, прежде чем выходить на арену.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    if let lastResult {
                        VStack(spacing: 6) {
                            Text(lastResult.won ? "Победа! 🎉" : "Поражение").font(.headline)
                                .foregroundStyle(lastResult.won ? .green : .red)
                            Text("\(lastResult.myPower) vs \(lastResult.opponentPower) — \(lastResult.opponentLabel)")
                                .font(.footnote).foregroundStyle(.secondary)
                            Text("\(lastResult.pointsDelta >= 0 ? "+" : "")\(lastResult.pointsDelta) очков")
                                .font(.footnote.bold())
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
            }
            .disabled(isBusy)
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
