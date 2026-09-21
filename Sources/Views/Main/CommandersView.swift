import SwiftUI

/// The "Полководцы" screen — Api\CommanderController (travianz-laravel), same CommanderService
/// the web Commanders/Index.vue page uses: owned collection, recruit-for-crystals gacha, and
/// picking the 5-slot arena squad.
struct CommandersView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var collection: CommanderCollection?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var lastRecruitMessage: String?

    var body: some View {
        content
            .gameListBackground()
            .withScreenTitle { ScreenTitleBar("Полководцы") }
            .task {
                guard collection == nil else { return }
                await load()
            }
            .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && collection == nil {
            ProgressView("Загрузка…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить полководцев").font(.headline)
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Повторить") { Task { await load() } }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let collection {
            List {
                Section {
                    Text("Бонусы коллекции: +\(Int(collection.bonuses.attack))% атака, +\(Int(collection.bonuses.defense))% защита, +\(Int(collection.bonuses.production))% добыча")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await recruit() }
                    } label: {
                        Label("Нанять за \(collection.recruitCost) 💎", systemImage: "person.badge.plus")
                    }
                    .buttonStyle(.gamePrimary)
                    .disabled(isBusy)
                    if let lastRecruitMessage {
                        Text(lastRecruitMessage).font(.footnote).foregroundStyle(GameTheme.good)
                    }
                }

                Section("Отряд (\(squadFilledCount(collection))/\(collection.maxSquadSize))") {
                    ForEach(1...collection.maxSquadSize, id: \.self) { slot in
                        if let commander = collection.squad["\(slot)"] ?? nil {
                            HStack {
                                Text("\(commander.icon) \(commander.label)").font(.footnote)
                                Spacer()
                                Text("Ур. \(commander.level)").font(.caption).foregroundStyle(.secondary)
                                Button("Убрать") { Task { await removeFromSquad(commander) } }
                                    .buttonStyle(.gameSecondary)
                                    .fixedSize()
                            }
                        } else {
                            Text("Пустой слот \(slot)").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Коллекция (\(collection.owned.count))") {
                    if collection.owned.isEmpty {
                        Text("Пока нет полководцев — наймите первого выше.").foregroundStyle(.secondary)
                    }
                    ForEach(collection.owned) { commander in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(commander.icon) \(commander.label)").font(.footnote)
                                Text("Ур. \(commander.level)/\(commander.maxLevel) · сила \(commander.power) · \(commander.rarity)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if commander.slot == nil {
                                Button("В отряд") { Task { await addToSquad(commander) } }
                                    .buttonStyle(.gamePrimary)
                                    .fixedSize()
                                    .disabled(isBusy || squadFilledCount(collection) >= collection.maxSquadSize)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .disabled(isBusy)
        } else {
            Color.clear
        }
    }

    private func squadFilledCount(_ collection: CommanderCollection) -> Int {
        (1...collection.maxSquadSize).filter { (collection.squad["\($0)"] ?? nil) != nil }.count
    }

    private func load() async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            collection = try await APIClient.shared.fetchCommanders(token: token)
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
        isLoading = false
    }

    private func recruit() async {
        guard let token = session.bearerToken else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.recruitCommander(token: token)
            lastRecruitMessage = "Полководец получен!"
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    private func currentSquadIDs(_ collection: CommanderCollection) -> [Int] {
        (1...collection.maxSquadSize).compactMap { (collection.squad["\($0)"] ?? nil)?.id }
    }

    private func addToSquad(_ commander: Commander) async {
        guard let token = session.bearerToken, let collection else { return }
        isBusy = true
        defer { isBusy = false }
        var ids = currentSquadIDs(collection)
        ids.append(commander.id)
        do {
            try await APIClient.shared.setCommanderSquad(commanderIDs: ids, token: token)
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    private func removeFromSquad(_ commander: Commander) async {
        guard let token = session.bearerToken, let collection else { return }
        isBusy = true
        defer { isBusy = false }
        let ids = currentSquadIDs(collection).filter { $0 != commander.id }
        do {
            try await APIClient.shared.setCommanderSquad(commanderIDs: ids, token: token)
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }
}
