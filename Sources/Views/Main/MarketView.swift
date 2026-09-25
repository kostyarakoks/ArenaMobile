import SwiftUI

/// The "Рынок" tab — Api\MarketController (travianz-laravel), same MarketService/EquipmentService
/// the web Market/Index.vue page uses. Two sub-tabs: resource-for-resource offers, and the item
/// market (hero equipment traded for resources).
struct MarketView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var villages: [VillageSummary] = []
    @State private var selectedVillageID: Int?
    @State private var detail: MarketDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var tab = 0
    @State private var showCreateOffer = false
    @State private var showSellItem = false

    var body: some View {
        content
            .gameListBackground()
            .withScreenTitle {
                ScreenTitleBar(detail?.village.name.isEmpty == false ? "Рынок — \(detail!.village.name)" : "Рынок") {
                    if villages.count > 1 {
                        Menu {
                            ForEach(villages) { village in
                                Button(village.name) {
                                    selectedVillageID = village.id
                                    Task { await load() }
                                }
                            }
                        } label: { Image(systemName: "list.bullet").foregroundStyle(GameTheme.amber) }
                    }
                }
            }
            .task {
                guard villages.isEmpty else { return }
                await loadVillages()
            }
            .refreshable { await load() }
            .sheet(isPresented: $showCreateOffer) {
                CreateResourceOfferSheet { offerResource, offerAmount, requestResource, requestAmount in
                    await createOffer(offerResource: offerResource, offerAmount: offerAmount, requestResource: requestResource, requestAmount: requestAmount)
                }
            }
            .sheet(isPresented: $showSellItem) {
                if let detail {
                    SellItemSheet(sellable: detail.sellableItems) { itemKey, resource, amount in
                        await sellItem(itemKey: itemKey, priceResource: resource, priceAmount: amount)
                    }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && detail == nil {
            ProgressView("Загрузка рынка…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить рынок").font(.headline)
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Повторить") { Task { await load() } }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let detail {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text("Ресурсы").tag(0)
                    Text("Предметы").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(12)

                if tab == 0 {
                    resourceTab(detail)
                } else {
                    itemTab(detail)
                }
            }
            .disabled(isBusy)
            .gameScreenBackground()
        } else {
            Color.clear
        }
    }

    // Широкая иллюстрация рынка прямо под вкладками — тот же приём, что и у героя
    // (см. HeroView.heroBanner), только тут картинка уже есть (прислана как готовый
    // ассет), а не заглушка.
    private var marketBanner: some View {
        Image("MarketBanner")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(GameTheme.panelBorder, lineWidth: 1))
    }

    private func resourceTab(_ detail: MarketDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                marketBanner

                Button {
                    showCreateOffer = true
                } label: {
                    Label("Создать предложение", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.gamePrimary)

                if !detail.mine.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Мои предложения").font(.subheadline.bold()).foregroundStyle(GameTheme.amber)
                        ForEach(detail.mine) { offer in
                            VStack(alignment: .leading, spacing: 8) {
                                offerLabel(give: offer.offerResource, giveAmount: offer.offerAmount, want: offer.requestResource, wantAmount: offer.requestAmount)
                                Button("Отменить") { Task { await cancelResourceOffer(id: offer.id) } }
                                    .buttonStyle(.gameSecondary)
                            }
                            .gamePanel(padding: 14)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Предложения игроков").font(.subheadline.bold()).foregroundStyle(GameTheme.amber)
                    if detail.offers.isEmpty {
                        Text("Пока нет предложений.")
                            .foregroundStyle(GameTheme.textMuted)
                            .gamePanel(padding: 14)
                    }
                    ForEach(detail.offers) { offer in
                        VStack(alignment: .leading, spacing: 6) {
                            offerLabel(give: offer.offerResource, giveAmount: offer.offerAmount, want: offer.requestResource, wantAmount: offer.requestAmount)
                            Text("\(offer.seller) · \(offer.village)").font(.caption2).foregroundStyle(GameTheme.textSecondary)
                            Button("Обменять") { Task { await acceptResourceOffer(id: offer.id) } }
                                .buttonStyle(.gamePrimary)
                        }
                        .gamePanel(padding: 14)
                    }
                }
            }
            .padding(16)
        }
    }

    // Строка обмена в стиле референса: "Дерево 100 → 100 Камень" с иконками ресурсов
    // вместо эмодзи-заглушек по бокам стрелки.
    private func offerLabel(give: String, giveAmount: Int, want: String, wantAmount: Int) -> some View {
        HStack(spacing: 8) {
            resourcePill(give, giveAmount)
            Image(systemName: "arrow.right").font(.footnote.bold()).foregroundStyle(GameTheme.amberLight)
            resourcePill(want, wantAmount)
        }
    }

    private func resourcePill(_ resource: String, _ amount: Int) -> some View {
        HStack(spacing: 4) {
            Text(icon(for: resource)).font(.footnote)
            Text("\(amount)").font(.footnote.bold()).foregroundStyle(GameTheme.textPrimary)
        }
    }

    private func icon(for resource: String) -> String {
        GameResource(rawValue: resource)?.icon ?? "❔"
    }

    private func itemTab(_ detail: MarketDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                marketBanner

                Button {
                    showSellItem = true
                } label: {
                    Label("Выставить предмет", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.gamePrimary)

                if !detail.myItemOffers.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Мои предметы").font(.subheadline.bold()).foregroundStyle(GameTheme.amber)
                        ForEach(detail.myItemOffers) { offer in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(offer.label) — \(icon(for: offer.priceResource)) \(offer.priceAmount)")
                                    .font(.footnote)
                                    .foregroundStyle(GameTheme.textPrimary)
                                Button("Отменить") { Task { await cancelItemOffer(id: offer.id) } }
                                    .buttonStyle(.gameSecondary)
                            }
                            .gamePanel(padding: 14)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Предметы игроков").font(.subheadline.bold()).foregroundStyle(GameTheme.amber)
                    if detail.itemOffers.isEmpty {
                        Text("Пока нет предложений.")
                            .foregroundStyle(GameTheme.textMuted)
                            .gamePanel(padding: 14)
                    }
                    ForEach(detail.itemOffers) { offer in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(offer.icon) \(offer.label)").font(.footnote).foregroundStyle(GameTheme.textPrimary)
                            Text("\(offer.seller) · \(offer.village) · \(icon(for: offer.priceResource)) \(offer.priceAmount)")
                                .font(.caption2)
                                .foregroundStyle(GameTheme.textSecondary)
                            Button("Купить") { Task { await acceptItemOffer(id: offer.id) } }
                                .buttonStyle(.gamePrimary)
                        }
                        .gamePanel(padding: 14)
                    }
                }
            }
            .padding(16)
        }
    }

    private func loadVillages() async {
        guard let token = session.bearerToken else { return }
        do {
            let list = try await APIClient.shared.fetchVillages(token: token)
            villages = list
            selectedVillageID = (list.first(where: { $0.isCapital }) ?? list.first)?.id
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
            isLoading = false
        }
    }

    private func load() async {
        guard let token = session.bearerToken, let id = selectedVillageID else { isLoading = false; return }
        isLoading = true
        errorMessage = nil
        do {
            detail = try await APIClient.shared.fetchMarket(villageID: id, token: token)
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
        isLoading = false
    }

    private func createOffer(offerResource: String, offerAmount: Int, requestResource: String, requestAmount: Int) async {
        guard let token = session.bearerToken, let id = selectedVillageID else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.createResourceOffer(villageID: id, offerResource: offerResource, offerAmount: offerAmount, requestResource: requestResource, requestAmount: requestAmount, token: token)
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    private func acceptResourceOffer(id offerID: Int) async {
        guard let token = session.bearerToken, let id = selectedVillageID else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.acceptResourceOffer(villageID: id, offerID: offerID, token: token)
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    private func cancelResourceOffer(id offerID: Int) async {
        guard let token = session.bearerToken, let id = selectedVillageID else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.cancelResourceOffer(villageID: id, offerID: offerID, token: token)
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    private func sellItem(itemKey: String, priceResource: String, priceAmount: Int) async {
        guard let token = session.bearerToken, let id = selectedVillageID else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.createItemOffer(villageID: id, itemKey: itemKey, priceResource: priceResource, priceAmount: priceAmount, token: token)
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    private func acceptItemOffer(id offerID: Int) async {
        guard let token = session.bearerToken, let id = selectedVillageID else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.acceptItemOffer(villageID: id, offerID: offerID, token: token)
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    private func cancelItemOffer(id offerID: Int) async {
        guard let token = session.bearerToken, let id = selectedVillageID else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.cancelItemOffer(villageID: id, offerID: offerID, token: token)
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }
}

private struct CreateResourceOfferSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSubmit: (String, Int, String, Int) async -> Void

    @State private var offerResource = GameResource.wood
    @State private var offerAmount = 100
    @State private var requestResource = GameResource.clay
    @State private var requestAmount = 100

    var body: some View {
        NavigationStack {
            Form {
                Section("Отдаю") {
                    Picker("Ресурс", selection: $offerResource) {
                        ForEach(GameResource.allCases) { r in Text("\(r.icon) \(r.label)").tag(r) }
                    }
                    Stepper("Количество: \(offerAmount)", value: $offerAmount, in: 1...100_000, step: 50)
                }
                Section("Хочу получить") {
                    Picker("Ресурс", selection: $requestResource) {
                        ForEach(GameResource.allCases) { r in Text("\(r.icon) \(r.label)").tag(r) }
                    }
                    Stepper("Количество: \(requestAmount)", value: $requestAmount, in: 1...100_000, step: 50)
                }
            }
            .navigationTitle("Новое предложение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        Task {
                            await onSubmit(offerResource.rawValue, offerAmount, requestResource.rawValue, requestAmount)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

private struct SellItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sellable: HeroDetail.OwnedBySlot
    let onSubmit: (String, String, Int) async -> Void

    @State private var selectedItemKey: String?
    @State private var priceResource = GameResource.wood
    @State private var priceAmount = 200

    private var allItems: [HeroDetail.Item] { sellable.weapon + sellable.armor + sellable.trinket }

    var body: some View {
        NavigationStack {
            Form {
                Section("Предмет") {
                    if allItems.isEmpty {
                        Text("Нет свободных предметов для продажи.").foregroundStyle(.secondary)
                    }
                    Picker("Предмет", selection: $selectedItemKey) {
                        Text("Выберите").tag(String?.none)
                        ForEach(allItems) { item in
                            Text("\(item.icon) \(item.label)").tag(String?.some(item.itemKey))
                        }
                    }
                }
                Section("Цена") {
                    Picker("Ресурс", selection: $priceResource) {
                        ForEach(GameResource.allCases) { r in Text("\(r.icon) \(r.label)").tag(r) }
                    }
                    Stepper("Количество: \(priceAmount)", value: $priceAmount, in: 1...100_000, step: 50)
                }
            }
            .navigationTitle("Продать предмет")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Выставить") {
                        guard let key = selectedItemKey else { return }
                        Task {
                            await onSubmit(key, priceResource.rawValue, priceAmount)
                            dismiss()
                        }
                    }
                    .disabled(selectedItemKey == nil)
                }
            }
        }
    }
}
