import SwiftUI

/// The "Магазин" tab — Api\ShopController (travianz-laravel), same ShopService the web
/// Shop/Index.vue page uses: crystal packages (stub payment — see ShopService::buyCrystals()),
/// Plus unlock, and the crystal-bought item catalog.
struct ShopView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var detail: ShopDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isBusy = false

    var body: some View {
        content
            .navigationTitle("Магазин")
            .task {
                guard detail == nil else { return }
                await load()
            }
            .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && detail == nil {
            ProgressView("Загрузка магазина…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить магазин").font(.headline)
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Повторить") { Task { await load() } }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let detail {
            List {
                Section {
                    HStack {
                        Text("💎 Кристаллы").font(.headline).foregroundStyle(GameTheme.textPrimary)
                        Spacer()
                        Text("\(detail.crystals)").font(.headline.monospacedDigit()).foregroundStyle(GameTheme.amber)
                    }
                    if detail.plusActive {
                        Label("Plus активен", systemImage: "star.fill").foregroundStyle(.yellow).font(.footnote)
                    } else if let until = detail.plusTempUntil {
                        Text("Plus (временно) до \(until)").font(.footnote).foregroundStyle(GameTheme.textSecondary)
                    }
                }

                Section("Купить кристаллы") {
                    ForEach(detail.packages) { package in
                        HStack {
                            Text("💎 \(package.crystals)").foregroundStyle(GameTheme.textPrimary)
                            Spacer()
                            Button(package.priceLabel) { Task { await buy(packageID: package.id) } }
                                .buttonStyle(.gamePrimary)
                                .fixedSize()
                        }
                    }
                }

                if !detail.plusActive {
                    Section("Plus-аккаунт") {
                        Button("Разблокировать Plus (\(detail.plusQueueCost) 💎)") { Task { await unlockPlus() } }
                            .buttonStyle(.gamePrimary)
                        Button("Plus на \(detail.plusQueueTempDays) дн. (\(detail.plusQueueTempCost) 💎)") { Task { await unlockPlusTemp() } }
                            .buttonStyle(.gamePrimary)
                    }
                }

                Section("Товары") {
                    ForEach(detail.items) { item in
                        HStack {
                            Text("\(item.icon ?? "🎁") \(item.label)").font(.footnote).foregroundStyle(GameTheme.textPrimary)
                            Spacer()
                            if let remaining = item.stockRemaining {
                                Text("осталось \(remaining)").font(.caption2).foregroundStyle(GameTheme.textSecondary)
                            }
                            Button("\(item.costCrystals) 💎") { Task { await purchase(id: item.id) } }
                                .buttonStyle(.gamePrimary)
                                .fixedSize()
                                .disabled(!item.inStock)
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

    private func load() async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            detail = try await APIClient.shared.fetchShop(token: token)
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
        isLoading = false
    }

    private func buy(packageID: Int) async {
        guard let token = session.bearerToken else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.buyCrystals(packageID: packageID, token: token)
            // "при покупке кристаллов не сразу появляются на карте" — `load()` only refetches
            // THIS screen's own local `detail`; MapOverlayControls'/GameHeaderBar's crystal badge
            // reads `session.currentUser?.gold` (AuthSession), which `load()` never touches, so
            // it stayed stale until the next full session reload. refreshCurrentUser() is the
            // method AuthSession already documents for exactly this ("called after any action
            // that changes something GameUser carries") — it just wasn't being called from here.
            await load()
            await session.refreshCurrentUser()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    private func unlockPlus() async {
        guard let token = session.bearerToken else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.unlockPlusQueue(token: token)
            // Also spends crystals — same staleness fix as buy(packageID:) above.
            await load()
            await session.refreshCurrentUser()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    private func unlockPlusTemp() async {
        guard let token = session.bearerToken else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.unlockPlusQueueTemporary(token: token)
            // Also spends crystals — same staleness fix as buy(packageID:) above.
            await load()
            await session.refreshCurrentUser()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    private func purchase(id: Int) async {
        guard let token = session.bearerToken else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.purchaseShopItem(id: id, token: token)
            // Also spends crystals — same staleness fix as buy(packageID:) above.
            await load()
            await session.refreshCurrentUser()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }
}
