import SwiftUI

/// The "Задания" screen — Api\QuestController (travianz-laravel), same QuestService the web
/// Quests/Index.vue page uses: the starter quest chain, then a repeating "tail" of resource
/// drops on a cooldown timer.
struct QuestsView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var status: QuestStatus?
    @State private var villageID: Int?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var tab = 0

    var body: some View {
        content
            .gameListBackground()
            .withScreenTitle { ScreenTitleBar("Задания") }
            .task {
                guard status == nil else { return }
                await load()
            }
            .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && status == nil {
            ProgressView("Загрузка заданий…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить задания").font(.headline)
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Повторить") { Task { await load() } }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let status {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text("Задания (\(status.chainCompleted)/\(status.chainTotal))").tag(0)
                    Text("Награды").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(12)

                List {
                    ForEach(tab == 0 ? status.chain : status.tail) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.title.isEmpty ? item.key : item.title).font(.footnote.bold()).foregroundStyle(GameTheme.textPrimary)
                                Spacer()
                                Text(stateLabel(item.state)).font(.caption2).foregroundStyle(stateColor(item.state))
                            }
                            if !item.description.isEmpty {
                                Text(item.description).font(.caption2).foregroundStyle(GameTheme.textSecondary)
                            }
                            Text(rewardLabel(item)).font(.caption2).foregroundStyle(GameTheme.textSecondary)
                            if item.state == "ready" {
                                Button(tab == 0 ? "Забрать" : "Забрать награду") {
                                    Task { await claim(tail: tab == 1) }
                                }
                                .buttonStyle(.gamePrimary)
                                .disabled(isBusy)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .disabled(isBusy)
        } else {
            Color.clear
        }
    }

    private func stateLabel(_ state: String) -> String {
        switch state {
        case "done": return "✅ выполнено"
        case "ready": return "🎁 готово"
        case "cooldown": return "⏳ ожидание"
        case "pending": return "в процессе"
        default: return "заблокировано"
        }
    }

    private func stateColor(_ state: String) -> Color {
        switch state {
        case "done": return GameTheme.good
        case "ready": return GameTheme.amber
        case "cooldown": return .orange
        default: return GameTheme.textMuted
        }
    }

    private func rewardLabel(_ item: QuestItem) -> String {
        var parts = ["wood", "clay", "iron", "crop"].compactMap { key -> String? in
            guard let value = item.reward[key], value > 0 else { return nil }
            return "\(value)"
        }
        if item.gold > 0 { parts.append("\(item.gold) 💎") }
        return parts.isEmpty ? "" : "Награда: " + parts.joined(separator: "/")
    }

    private func load() async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            if villageID == nil {
                villageID = try await APIClient.shared.fetchVillages(token: token).first?.id
            }
            status = try await APIClient.shared.fetchQuests(villageID: villageID, token: token)
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
        isLoading = false
    }

    private func claim(tail: Bool) async {
        guard let token = session.bearerToken else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            if tail {
                try await APIClient.shared.claimQuestTail(villageID: villageID, token: token)
            } else {
                try await APIClient.shared.claimQuest(villageID: villageID, token: token)
            }
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }
}
