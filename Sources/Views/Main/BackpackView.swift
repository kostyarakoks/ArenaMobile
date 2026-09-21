import SwiftUI

/// The "Рюкзак" screen — Api\BackpackController (travianz-laravel), same InventoryService the
/// web Backpack/Index.vue page uses: owned items grouped by category, with a "use" action for
/// the ones that aren't purely cosmetic/equipment (equipment is used from HeroView instead).
struct BackpackView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var response: BackpackResponse?
    @State private var villages: [VillageSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isBusy = false

    var body: some View {
        content
            .gameListBackground()
            .safeAreaInset(edge: .top, spacing: 0) { ScreenTitleBar("Рюкзак") }
            .task {
                guard response == nil else { return }
                await load()
            }
            .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && response == nil {
            ProgressView("Загрузка рюкзака…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить рюкзак").font(.headline)
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Повторить") { Task { await load() } }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let response {
            List {
                ForEach(BackpackCategory.allCases) { category in
                    let items = response.items[category.rawValue] ?? []
                    if !items.isEmpty {
                        Section(category.label) {
                            ForEach(items) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(item.icon ?? "🎁") \(item.label)").font(.footnote)
                                        if let description = item.description, !description.isEmpty {
                                            Text(description).font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text("x\(item.quantity)").font(.caption).foregroundStyle(.secondary)
                                    if item.usable {
                                        Button("Использовать") { Task { await use(itemKey: item.itemKey) } }
                                            .buttonStyle(.gamePrimary)
                                            .fixedSize()
                                            .disabled(isBusy || villages.isEmpty)
                                    }
                                }
                            }
                        }
                    }
                }
                if BackpackCategory.allCases.allSatisfy({ (response.items[$0.rawValue] ?? []).isEmpty }) {
                    Text("Рюкзак пуст.").foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
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
            response = try await APIClient.shared.fetchBackpack(token: token)
            if villages.isEmpty {
                villages = (try? await APIClient.shared.fetchVillages(token: token)) ?? []
            }
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
        isLoading = false
    }

    private func use(itemKey: String) async {
        guard let token = session.bearerToken, let villageID = villages.first?.id else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.useBackpackItem(itemKey: itemKey, villageID: villageID, token: token)
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }
}
