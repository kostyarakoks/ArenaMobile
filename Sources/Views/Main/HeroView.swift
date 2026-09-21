import SwiftUI

/// The "Герой" tab's real content — Api\HeroController (travianz-laravel), same EquipmentService
/// the web Hero/Show.vue page uses. Stats + point allocation, equip/unequip from owned gear, and
/// crafting new items for the active village's resources.
struct HeroView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var detail: HeroDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isBusy = false
    // Craft needs a village_id (the mobile API is stateless — no server-side "active village"
    // session, unlike the web app; see HeroController::craft's docblock). Loaded once so the
    // craft buttons have something to send.
    @State private var villages: [VillageSummary] = []

    private static let attributes: [(key: String, label: String)] = [
        ("point_attack", "Сила атаки"),
        ("point_defense", "Сила обороны"),
        ("point_off_bonus", "Бонус атаки войск (%)"),
        ("point_def_bonus", "Бонус обороны войск (%)"),
    ]

    var body: some View {
        content
            .gameScreenBackground()
            .safeAreaInset(edge: .top, spacing: 0) { ScreenTitleBar("Герой") }
            .task {
                guard detail == nil else { return }
                await load()
            }
            .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && detail == nil {
            ProgressView("Загрузка героя…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить героя").font(.headline)
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Повторить") { Task { await load() } }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let detail {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statsSection(detail.hero)
                    pointsSection(detail.hero)
                    equipmentSection(detail.equipment)
                    craftSection(detail.equipment.craftable)
                }
                .padding(16)
            }
            .disabled(isBusy)
            .gameScreenBackground()
        } else {
            Color.clear
        }
    }

    private func statsSection(_ hero: HeroDetail.Info) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(hero.name).font(.title2.bold()).foregroundStyle(GameTheme.amber)
            if hero.isOnAdventure {
                Label("Герой в экспедиции", systemImage: "figure.walk").font(.footnote).foregroundStyle(.orange)
            }
            if let village = hero.village {
                Text("Находится в деревне: \(village)").font(.footnote).foregroundStyle(GameTheme.textSecondary)
            }
            HStack {
                Text("Уровень \(hero.level)").font(.subheadline.bold()).foregroundStyle(GameTheme.amber)
                Spacer()
                Text("\(hero.experience)/\(hero.experienceForNext) опыта").font(.footnote).foregroundStyle(GameTheme.textSecondary)
            }
            ProgressView(value: hero.experienceForNext > 0 ? Double(hero.experience) / Double(hero.experienceForNext) : 0)
                .tint(.yellow)
            HStack {
                Text("Здоровье").font(.footnote).foregroundStyle(GameTheme.textSecondary)
                Spacer()
                Text("\(hero.health)%").font(.footnote.bold()).foregroundStyle(GameTheme.textPrimary)
            }
            ProgressView(value: Double(hero.health) / 100)
                .tint(.green)
        }
        .gamePanel(padding: 14)
    }

    private func pointsSection(_ hero: HeroDetail.Info) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Свободные очки: \(hero.unspentPoints)").font(.subheadline.bold()).foregroundStyle(GameTheme.amber)
            ForEach(Self.attributes, id: \.key) { attr in
                let current = value(for: attr.key, in: hero)
                HStack {
                    Text(attr.label).font(.footnote).foregroundStyle(GameTheme.textPrimary)
                    Spacer()
                    Text("\(current)").font(.footnote.monospacedDigit()).foregroundStyle(GameTheme.textSecondary)
                    Button {
                        Task { await allocate(attribute: attr.key) }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.gamePrimary)
                    .fixedSize()
                    .disabled(hero.unspentPoints < 1 || isBusy)
                }
            }
        }
        .gamePanel(padding: 14)
    }

    private func value(for attribute: String, in hero: HeroDetail.Info) -> Int {
        switch attribute {
        case "point_attack": return hero.pointAttack
        case "point_defense": return hero.pointDefense
        case "point_off_bonus": return hero.pointOffBonus
        case "point_def_bonus": return hero.pointDefBonus
        default: return 0
        }
    }

    private func equipmentSection(_ equipment: HeroDetail.Equipment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Снаряжение").font(.subheadline.bold()).foregroundStyle(GameTheme.amber)
            Text("Бонус от очков и предметов: +\(equipment.bonusPercent.attack)% атака, +\(equipment.bonusPercent.defense)% защита")
                .font(.caption)
                .foregroundStyle(GameTheme.textSecondary)

            slotRow(label: "Оружие", equipped: equipment.equipped.weapon, owned: equipment.owned.weapon, slot: "weapon")
            slotRow(label: "Броня", equipped: equipment.equipped.armor, owned: equipment.owned.armor, slot: "armor")
            slotRow(label: "Амулет", equipped: equipment.equipped.trinket, owned: equipment.owned.trinket, slot: "trinket")
        }
        .gamePanel(padding: 14)
    }

    private func slotRow(label: String, equipped: HeroDetail.Item?, owned: [HeroDetail.Item], slot: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.footnote.bold()).foregroundStyle(GameTheme.textPrimary)
            if let equipped {
                HStack {
                    Text("\(equipped.icon) \(equipped.label)").font(.footnote).foregroundStyle(GameTheme.textPrimary)
                    Spacer()
                    Button("Снять") { Task { await unequip(slot: slot) } }
                        .buttonStyle(.gameSecondary)
                        .fixedSize()
                        .disabled(isBusy)
                }
            } else {
                Text("Пусто").font(.footnote).foregroundStyle(GameTheme.textMuted)
            }
            if !owned.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(owned) { item in
                            Button {
                                Task { await equip(slot: slot, itemKey: item.itemKey) }
                            } label: {
                                VStack(spacing: 2) {
                                    Text(item.icon).font(.title3)
                                    Text("x\(item.quantity)").font(.caption2).foregroundStyle(GameTheme.textSecondary)
                                }
                                .padding(6)
                                .background(GameTheme.panelBorder)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .disabled(isBusy)
                        }
                    }
                }
            }
        }
    }

    private func craftSection(_ craftable: [HeroDetail.CraftableItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Скрафтить").font(.subheadline.bold()).foregroundStyle(GameTheme.amber)
            ForEach(craftable) { item in
                HStack {
                    Text("\(item.icon) \(item.label)").font(.footnote).foregroundStyle(GameTheme.textPrimary)
                    Spacer()
                    Text(costLabel(item.cost)).font(.caption2).foregroundStyle(GameTheme.textSecondary)
                    Button("Создать") { Task { await craft(itemKey: item.key) } }
                        .buttonStyle(.gamePrimary)
                        .fixedSize()
                        .disabled(isBusy || villages.isEmpty)
                }
            }
        }
        .gamePanel(padding: 14)
    }

    private func costLabel(_ cost: [String: Int]) -> String {
        ["wood", "clay", "iron", "crop"]
            .compactMap { key in cost[key].map { "\($0)" } }
            .joined(separator: "/")
    }

    private func load() async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            detail = try await APIClient.shared.fetchHero(token: token)
            if villages.isEmpty {
                villages = (try? await APIClient.shared.fetchVillages(token: token)) ?? []
            }
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Неизвестная ошибка."
        }
        isLoading = false
    }

    private func allocate(attribute: String) async {
        guard let token = session.bearerToken else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.allocateHeroPoints(attribute: attribute, points: 1, token: token)
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    private func equip(slot: String, itemKey: String) async {
        guard let token = session.bearerToken else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.equipHeroItem(slot: slot, itemKey: itemKey, token: token)
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    private func unequip(slot: String) async {
        guard let token = session.bearerToken else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.unequipHeroItem(slot: slot, token: token)
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    private func craft(itemKey: String) async {
        guard let token = session.bearerToken, let villageID = villages.first?.id else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.craftHeroItem(itemKey: itemKey, villageID: villageID, token: token)
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }
}
