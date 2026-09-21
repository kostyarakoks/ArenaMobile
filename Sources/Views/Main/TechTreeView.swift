import SwiftUI

/// The "Технологии" screen — Api\TechTreeController (travianz-laravel): every building type's
/// requirements, grouped by tier (dependency depth) instead of the web version's rendered node
/// graph — same information, a plain list reads better on a phone than a pannable canvas would.
struct TechTreeView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var response: TechTreeResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        content
            .gameListBackground()
            .withScreenTitle { ScreenTitleBar("Технологии") }
            .task {
                guard response == nil else { return }
                await load()
            }
            .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && response == nil {
            ProgressView("Загрузка дерева технологий…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить дерево технологий").font(.headline)
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Повторить") { Task { await load() } }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let response {
            List {
                ForEach(0..<response.tierCount, id: \.self) { tier in
                    let nodes = response.nodes.filter { $0.tier == tier }
                    if !nodes.isEmpty {
                        Section("Уровень \(tier)") {
                            ForEach(nodes) { node in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(node.label).font(.footnote.bold()).foregroundStyle(GameTheme.textPrimary)
                                        Spacer()
                                        if node.isBuilt {
                                            Text("построено (\(node.currentLevel)/\(node.maxLevel))")
                                                .font(.caption2).foregroundStyle(GameTheme.good)
                                        } else if node.isAvailable {
                                            Text("доступно").font(.caption2).foregroundStyle(GameTheme.amber)
                                        } else {
                                            Text("заблокировано").font(.caption2).foregroundStyle(GameTheme.textMuted)
                                        }
                                    }
                                    if !node.requires.isEmpty {
                                        Text("Требует: " + node.requires.map { "\($0.label) ур.\($0.level)" }.joined(separator: ", "))
                                            .font(.caption2)
                                            .foregroundStyle(GameTheme.textSecondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        } else {
            Color.clear
        }
    }

    private func load() async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            let villages = try await APIClient.shared.fetchVillages(token: token)
            response = try await APIClient.shared.fetchTechTree(villageID: villages.first?.id, token: token)
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
        isLoading = false
    }
}
