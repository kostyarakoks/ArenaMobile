import SwiftUI

/// The "Поля" screen — native counterpart of Village/Fields.vue (dorf1): the 18 resource-field
/// tiles (Лесопилка/wood, Карьер/clay, Рудник/iron, Поле/crop) surrounding the village, each
/// independently upgradable, exactly mirroring VillageMapView's own building-plot map
/// (background art, pinch-zoom/pan via ZoomableMapContainer, live construction-progress badges,
/// tap-to-upgrade sheet) but pointed at Api\VillageController::fields()/fieldAction() instead of
/// slot()/slotAction().
///
/// Added per the explicit request "кнопку «поля» вынести из общего в карту, таже добавить сами
/// поля" — "Поля" used to be a dead PlaceholderScreen tucked in the "Ещё" sheet (see
/// NavDestinationView's old `default:` fallthrough); it's now a real screen, reachable straight
/// from the map via MapOverlayControls' own button stack instead.
struct FieldsMapView: View {
    @EnvironmentObject private var session: AuthSession
    @EnvironmentObject private var villageSession: VillageSession

    var selectItem: (NavItem) -> Void = { _ in }

    @State private var response: FieldsResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var tappedFieldID: Int?
    // Same throttled "did anything just finish" poll VillageMapView.swift uses for the building
    // map — see its own doc comment for why this exists (construction badges otherwise sit at
    // 0:00 forever once a field's queue entry passes finishes_at).
    @State private var lastConstructionRefreshAttempt: Date = .distantPast

    private static let queueDateFormatter = ISO8601DateFormatter()

    var body: some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .trailing) {
                MapOverlayControls(selectItem: selectItem)
                    .padding(.trailing, 12)
            }
            .task(id: villageSession.selectedVillageID) {
                await load()
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard let queue = response?.queue, !queue.isEmpty else { continue }
                    let hasFinished = queue.contains { entry in
                        guard let finishes = Self.queueDateFormatter.date(from: entry.finishesAt) else { return false }
                        return finishes <= .now
                    }
                    guard hasFinished, Date.now.timeIntervalSince(lastConstructionRefreshAttempt) > 3 else { continue }
                    lastConstructionRefreshAttempt = .now
                    await load()
                }
            }
            .sheet(item: Binding(get: { tappedFieldID.map { IdentifiableSlotID(id: $0) } }, set: { tappedFieldID = $0?.id })) { wrapped in
                if let response, let field = response.fields.first(where: { $0.id == wrapped.id }), let villageID = villageSession.selectedVillageID {
                    FieldActionSheet(
                        villageID: villageID,
                        field: field,
                        village: response.village,
                        queueFull: response.queueFull,
                        onChanged: { Task { await load() } }
                    )
                    .presentationDetents([.medium, .large])
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && response == nil {
            ProgressView("Загрузка полей…")
                .tint(GameTheme.amber)
                .foregroundStyle(GameTheme.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gameScreenBackground()
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить поля").font(.headline).foregroundStyle(GameTheme.textPrimary)
                Text(errorMessage).font(.footnote).foregroundStyle(GameTheme.textMuted).multilineTextAlignment(.center)
                Button("Повторить") { Task { await load() } }
                    .buttonStyle(.gamePrimary)
                    .frame(width: 160)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gameScreenBackground()
        } else if let response {
            mapCanvas(response)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gameScreenBackground()
        } else {
            Color.clear.gameScreenBackground()
        }
    }

    private func mapCanvas(_ response: FieldsResponse) -> some View {
        let width = FieldLayout.viewboxWidth
        let height = FieldLayout.viewboxHeight
        let fieldsBySlot: [Int: FieldSummary] = response.fields.reduce(into: [:]) { acc, f in acc[f.slot] = f }
        // Mirrors VillageMapView's own fix — village_fields.slot and village_buildings.slot share
        // the same numeric range, so this map must only look at "field" queue entries or it can
        // pick up a same-numbered BUILDING's queue entry instead of this field's own.
        let queueBySlot: [Int: VillageDetail.QueueEntry] = response.queue
            .filter { $0.queueType == "field" }
            .reduce(into: [:]) { acc, item in
                if let existing = acc[item.slot], existing.startedAt <= item.startedAt { return }
                acc[item.slot] = item
            }

        return ZoomableMapContainer(contentAspect: CGFloat(width / height)) {
            GeometryReader { geo in
                let scaleX = geo.size.width / width
                let scaleY = geo.size.height / height
                let markerScale = min(scaleX, scaleY)

                ZStack {
                    backgroundImage
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()

                    ForEach(FieldLayout.coords.keys.sorted(), id: \.self) { slot in
                        if let coord = FieldLayout.coords[slot], let field = fieldsBySlot[slot] {
                            fieldMarker(field: field, queueEntry: queueBySlot[slot], scale: markerScale)
                                .position(x: coord.cx * scaleX, y: coord.cy * scaleY)
                        }
                    }
                }
            }
        }
    }

    // Not bundled locally (only one variant exists — see FieldLayout.backgroundPath's own doc
    // comment), so this always AsyncImage-fetches against whatever server the player logged
    // into, with a plain fallback fill while it loads.
    private var backgroundImage: some View {
        let url = URL(string: FieldLayout.backgroundPath, relativeTo: APIClient.shared.baseURL)?.absoluteURL
        return AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                GameTheme.background
            }
        }
    }

    private func fieldMarker(field: FieldSummary, queueEntry: VillageDetail.QueueEntry?, scale: CGFloat) -> some View {
        let iconSize: CGFloat = 26 * scale

        return Button {
            tappedFieldID = field.id
        } label: {
            ZStack {
                Image(field.iconAssetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .padding(6 * scale)
                    .background(Circle().fill(Color.black.opacity(0.4)))
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1 * scale))

                if let queueEntry {
                    ConstructionBadge(entry: queueEntry, scale: scale)
                        .offset(y: iconSize / 2 + 18 * scale)
                } else {
                    Text("\(field.level)")
                        .font(.system(size: 10 * scale, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4 * scale)
                        .padding(.vertical, 1 * scale)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Capsule())
                        .offset(y: iconSize / 2 + 11 * scale)
                }
            }
            .shadow(color: .black.opacity(0.5), radius: 2 * scale)
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        guard let token = session.bearerToken, let villageID = villageSession.selectedVillageID else { return }
        isLoading = true
        errorMessage = nil
        do {
            response = try await APIClient.shared.fetchFields(villageID: villageID, token: token)
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Неизвестная ошибка."
        }
        isLoading = false
    }
}

/// Cost/time/bonus + upgrade/instant-finish actions for one resource field — same shape as
/// VillageMapView's BuildingDetailCard, just without a "what could go here instead" picker
/// (a field's type never changes, see FieldSummary's own doc comment).
private struct FieldActionSheet: View {
    @EnvironmentObject private var session: AuthSession
    @Environment(\.dismiss) private var dismiss

    let villageID: Int
    let field: FieldSummary
    let village: FieldsResponse.FieldsVillageInfo
    let queueFull: Bool
    let onChanged: () -> Void

    @State private var isBusy = false
    @State private var errorMessage: String?

    private var isMaxed: Bool { field.level >= field.maxLevel }
    private var have: [String: Int] { ["wood": village.wood, "clay": village.clay, "iron": village.iron, "crop": village.crop] }

    private var canAffordCost: Bool {
        guard let cost = field.nextCost else { return false }
        return village.wood >= cost.wood && village.clay >= cost.clay && village.iron >= cost.iron && village.crop >= cost.crop
    }

    private var canUpgrade: Bool { !isBusy && !isMaxed && !queueFull && canAffordCost }
    private var canFinishInstant: Bool { canUpgrade && (session.currentUser?.gold ?? 0) >= (field.instantFinishCost ?? Int.max) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(field.iconAssetName).resizable().aspectRatio(contentMode: .fit).frame(width: 44, height: 44)
                        Text(field.label).font(.headline).foregroundStyle(GameTheme.textPrimary)
                    }

                    Text(isMaxed ? "Достигнут максимальный уровень" : "Уровень \(field.level) → \(field.level + 1)")
                        .font(.subheadline.bold())
                        .foregroundStyle(GameTheme.amber)

                    if !isMaxed {
                        if let bonus = field.bonusNext ?? field.bonusCurrent {
                            boxSection(title: "Бонус") {
                                HStack {
                                    Text(bonus.label).foregroundStyle(GameTheme.textPrimary)
                                    Spacer()
                                    if let current = field.bonusCurrent {
                                        Text("\(current.value)\(current.suffix)").foregroundStyle(GameTheme.textPrimary)
                                        if field.bonusNext != nil {
                                            Text(" → \(bonus.value)\(bonus.suffix)").foregroundStyle(GameTheme.good)
                                        }
                                    } else {
                                        Text("\(bonus.value)\(bonus.suffix)").foregroundStyle(GameTheme.textPrimary)
                                    }
                                }
                                .font(.footnote)
                            }
                        }

                        if let cost = field.nextCost {
                            boxSection(title: "Стоимость") {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 14) {
                                        costItem(icon: "🌲", need: cost.wood, have: have["wood"] ?? 0)
                                        costItem(icon: "🧱", need: cost.clay, have: have["clay"] ?? 0)
                                        costItem(icon: "⛏️", need: cost.iron, have: have["iron"] ?? 0)
                                        costItem(icon: "🌾", need: cost.crop, have: have["crop"] ?? 0)
                                    }
                                    if let time = field.nextTime {
                                        Text("Время постройки: \(formatTime(time))")
                                            .font(.caption2)
                                            .foregroundStyle(GameTheme.textMuted)
                                    }
                                }
                            }
                        }

                        if queueFull {
                            Text("Очередь строительства заполнена — дождитесь завершения текущей постройки.")
                                .font(.caption)
                                .foregroundStyle(GameTheme.bad)
                                .padding(8)
                                .background(GameTheme.bad.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        if let errorMessage {
                            Text(errorMessage).font(.caption).foregroundStyle(GameTheme.bad)
                        }

                        HStack(spacing: 10) {
                            Button {
                                Task { await performAction(instant: true) }
                            } label: {
                                Text("Завершить\(field.instantFinishCost.map { " (\($0)💎)" } ?? "")")
                            }
                            .buttonStyle(.gameSecondary)
                            .disabled(!canFinishInstant)

                            Button {
                                Task { await performAction(instant: false) }
                            } label: {
                                Text("Улучшить")
                            }
                            .buttonStyle(.gamePrimary)
                            .disabled(!canUpgrade)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle(field.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }
            }
            .gameScreenBackground()
        }
    }

    private func performAction(instant: Bool) async {
        guard let token = session.bearerToken else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.upgradeField(villageID: villageID, fieldID: field.id, instant: instant, token: token)
            onChanged()
            dismiss()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Неизвестная ошибка."
        }
    }

    private func boxSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(GameTheme.amber)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GameTheme.panelBorder)
            content()
                .padding(10)
        }
        .background(GameTheme.panelTop.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(GameTheme.panelBorder, lineWidth: 1))
    }

    private func costItem(icon: String, need: Int, have: Int) -> some View {
        VStack(spacing: 1) {
            Text(icon).font(.footnote)
            Text("\(need)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(have >= need ? GameTheme.good : GameTheme.bad)
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
