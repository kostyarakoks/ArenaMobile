import SwiftUI

/// The "Исследования" screen — Api\ResearchController (travianz-laravel), same ResearchService
/// the web Research/Index.vue page uses: the tribe's research chain, what's already researched,
/// and starting the next one (spends the account's first village's resources — see the
/// controller's docblock for why the app must pick a village explicitly).
struct ResearchView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var detail: ResearchDetail?
    @State private var villages: [VillageSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isBusy = false

    var body: some View {
        content
            .navigationTitle("Исследования")
            .task {
                guard detail == nil else { return }
                await load()
            }
            .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && detail == nil {
            ProgressView("Загрузка…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить исследования").font(.headline)
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Повторить") { Task { await load() } }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let detail {
            List {
                Section {
                    Text("Уровень академии: \(detail.academyLevel)").font(.footnote)
                    if let active = detail.active {
                        Text("Сейчас изучается: \(active.label)").font(.footnote).foregroundStyle(.orange)
                    }
                }
                Section("Цепочка исследований") {
                    ForEach(detail.chain) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.label).font(.footnote.bold())
                                if entry.isResearched {
                                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).font(.caption)
                                }
                                Spacer()
                            }
                            if let description = entry.description, !description.isEmpty {
                                Text(description).font(.caption2).foregroundStyle(.secondary)
                            }
                            Text(costLabel(entry.cost)).font(.caption2).foregroundStyle(.secondary)
                            if !entry.isResearched {
                                Button("Изучить") { Task { await start(key: entry.key) } }
                                    .font(.caption)
                                    .disabled(isBusy || !entry.isAvailable || detail.active != nil)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .disabled(isBusy)
        } else {
            Color.clear
        }
    }

    private func costLabel(_ cost: [String: Int]) -> String {
        ["wood", "clay", "iron", "crop"].compactMap { cost[$0].map { "\($0)" } }.joined(separator: "/")
    }

    private func load() async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            detail = try await APIClient.shared.fetchResearch(token: token)
            if villages.isEmpty {
                villages = (try? await APIClient.shared.fetchVillages(token: token)) ?? []
            }
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
        isLoading = false
    }

    private func start(key: String) async {
        guard let token = session.bearerToken, let villageID = villages.first?.id else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.startResearch(key: key, villageID: villageID, token: token)
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }
}
