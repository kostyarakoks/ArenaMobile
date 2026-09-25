import SwiftUI

/// The "Город" tab's real content.
///
/// Layout:
///   • Карта растянута на ВЕСЬ экран и заходит ПОД глобальный хедер (с ресурсами),
///     под нижний док MainTabView и под полосу с именем деревни. Всё это — оверлеи
///     поверх карты, а не отдельные полосы, отнимающие у неё место.
///   • .safeAreaInset(edge: .top) { villageNameBar } — полоса "📍 {имя}"
///     встаёт на верхнюю кромку контентной зоны (сразу под глобальным хедером).
///   • .overlay(alignment: .topTrailing) — столбец круглых кнопок справа.
///
/// Зум: minZoom = 1.0 (aspect fill — карта ровно покрывает экран),
/// maxZoom = 2.0 (максимум ×2).
struct VillageMapView: View {
    @EnvironmentObject private var session: AuthSession
    @EnvironmentObject private var villageSession: VillageSession

    var selectItem: (NavItem) -> Void = { _ in }

    @State private var tappedSlot: Int?
    @State private var lastConstructionRefreshAttempt: Date = .distantPast

    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var renameError: String?
    @State private var isRenameSaving = false

    // Дефолтные размеры viewbox. Соотношение 940:1672 ≈ 0.562 — портретная
    // карта, шире соотношение экрана. Aspect fill в ZoomableMapContainer
    // растянет её на весь экран без чёрных полос.
    private static let defaultMapWidth: Int = 940
    private static let defaultMapHeight: Int = 1672

    private var selectedVillageID: Int? { villageSession.selectedVillageID }
    private var detail: VillageDetail? { villageSession.detail }
    private var isLoading: Bool { villageSession.isLoading }
    private var errorMessage: String? { villageSession.errorMessage }

    var body: some View {
        ZStack {
            // Карта — растянута на весь экран и ЗАХОДИТ под глобальный хедер
            // и под нижний док. .ignoresSafeArea() здесь, внутри ZStack, а не
            // на самом ZStack: так mapCanvas гарантированно занимает полный
            // экран, включая области под safeAreaInset'ами родителя.
            if let detail {
                mapCanvas(detail)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            }

            if let errorMessage, detail == nil, !isLoading {
                errorStateView(errorMessage)
            }
        }
        // Полоса с именем деревни — safeAreaInset на ZStack, встаёт поверх карты
        // сразу под глобальным хедером. Градиент 50% → 0% — карта просвечивает
        // сквозь нижнюю часть полосы.
        .safeAreaInset(edge: .top, spacing: 0) {
            villageNameBar
        }
        .overlay(alignment: .topTrailing) {
            mapActionColumn
                .padding(.trailing, 10)
                .padding(.top, 8)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await villageSession.loadIfNeeded(session)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let queue = villageSession.detail?.queue, !queue.isEmpty else { continue }
                let hasFinished = queue.contains { entry in
                    guard let finishes = ISO8601DateFormatter().date(from: entry.finishesAt) else { return false }
                    return finishes <= .now
                }
                guard hasFinished, Date.now.timeIntervalSince(lastConstructionRefreshAttempt) > 3 else { continue }
                lastConstructionRefreshAttempt = .now
                villageSession.refreshSelected(session)
            }
        }
        .sheet(item: Binding(get: { tappedSlot.map { IdentifiableSlotID(id: $0) } }, set: { tappedSlot = $0?.id })) { wrapped in
            if let detail, let villageID = selectedVillageID {
                SlotActionSheet(
                    villageID: villageID,
                    slot: wrapped.id,
                    builtSlot: detail.buildings.first(where: { $0.slot == wrapped.id }),
                    village: detail.village,
                    onChanged: { villageSession.refreshSelected(session) }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $isRenaming) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Название деревни", text: $renameText)
                            .disabled(isRenameSaving)
                    } footer: {
                        if let renameError {
                            Text(renameError).foregroundStyle(GameTheme.bad)
                        }
                    }
                }
                .navigationTitle("Переименовать деревню")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { isRenaming = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if isRenameSaving {
                            ProgressView()
                        } else {
                            Button("Сохранить") { Task { await performRename() } }
                                .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .presentationDetents([.height(190)])
        }
    }

    // MARK: - Полоса с именем деревни

    @ViewBuilder
    private var villageNameBar: some View {
        if let detail {
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(GameTheme.amberLight)

                Text(detail.village.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.6), radius: 2)

                if detail.village.canRename {
                    Button {
                        renameText = detail.village.name
                        renameError = nil
                        isRenaming = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(GameTheme.amberLight.opacity(0.9))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.5),
                        Color.black.opacity(0.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
            )
        }
    }

    // MARK: - Столбец кнопок справа

    private var mapActionColumn: some View {
        VStack(spacing: 10) {
            mapActionButton(icon: "leaf.fill", badge: nil) {
                // TODO: открыть экран полей/ресурсов
            }
            mapActionButton(icon: "gearshape.fill", badge: nil) {
                // TODO: открыть настройки
            }
            mapActionButton(icon: "envelope.fill", badge: 1) {
                // TODO: открыть сообщения
            }
            mapActionButton(icon: "scroll.fill", badge: nil) {
                // TODO: открыть квесты
            }
        }
    }

    private func mapActionButton(
        icon: String,
        badge: Int?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.13, green: 0.20, blue: 0.36),
                                Color(red: 0.08, green: 0.13, blue: 0.26),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(GameTheme.amberLight.opacity(0.7), lineWidth: 1.2)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(GameTheme.amberLight)
                    .frame(width: 46, height: 46)

                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 4, y: -4)
                }
            }
            .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Карта

    private func mapCanvas(_ detail: VillageDetail) -> some View {
        let width = Double(detail.map.viewboxWidth ?? Self.defaultMapWidth)
        let height = Double(detail.map.viewboxHeight ?? Self.defaultMapHeight)

        let coordsBySlot: [Int: (cx: Double, cy: Double)] = {
            if let serverCoords = detail.map.coords, !serverCoords.isEmpty {
                return serverCoords.reduce(into: [:]) { acc, c in acc[c.slot] = (cx: c.cx, cy: c.cy) }
            }
            return VillageLayout.coords
        }()
        let backgroundPath = detail.map.background ?? VillageLayout.backgroundPath(tribe: detail.tribe, wallLevel: detail.wallLevel)
        let buildingsBySlot: [Int: VillageDetail.BuildingSlot] = detail.buildings.reduce(into: [:]) { acc, b in acc[b.slot] = b }
        let queueBySlot: [Int: VillageDetail.QueueEntry] = detail.queue
            .filter { $0.queueType == "building" }
            .reduce(into: [:]) { acc, item in
                if let existing = acc[item.slot], existing.startedAt <= item.startedAt { return }
                acc[item.slot] = item
            }

        let mainBuildingSlot = detail.buildings.first(where: { $0.buildingKey == "main_building" })?.slot ?? 8
        let initialCenterFraction: CGPoint? = coordsBySlot[mainBuildingSlot].map {
            CGPoint(x: $0.cx / width, y: $0.cy / height)
        }

        return ZoomableMapContainer(
            minZoom: 1.0,
            maxZoom: 2.0,
            contentAspect: CGFloat(width / height),
            initialCenterFraction: initialCenterFraction,
            content: {
                GeometryReader { geo in
                    let scaleX = geo.size.width / width
                    let scaleY = geo.size.height / height

                    ZStack {
                        backgroundImage(path: backgroundPath)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()

                        RadialGradient(
                            colors: [Color(red: 1, green: 0.77, blue: 0.42).opacity(0.35), Color(red: 1, green: 0.71, blue: 0.33).opacity(0)],
                            center: .center, startRadius: 1, endRadius: max(geo.size.width, geo.size.height) * 0.22
                        )
                        .frame(width: geo.size.width * 0.46, height: geo.size.height * 0.46)
                        .allowsHitTesting(false)

                        let markerScale = min(scaleX, scaleY)
                        ForEach(coordsBySlot.keys.sorted(), id: \.self) { slot in
                            if let coord = coordsBySlot[slot] {
                                plotMarker(slot: slot, building: buildingsBySlot[slot], queueEntry: queueBySlot[slot], scale: markerScale)
                                    .position(x: coord.cx * scaleX, y: coord.cy * scaleY)
                            }
                        }
                    }
                }
            }
        )
    }

    // MARK: - Фон карты

    @ViewBuilder
    private func backgroundImage(path: String) -> some View {
        if let assetName = VillageLayout.backgroundAssetName(forPath: path) {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            let url = URL(string: path, relativeTo: APIClient.shared.baseURL)?.absoluteURL
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    GameTheme.background
                }
            }
        }
    }

    // MARK: - Маркер участка

    private func plotMarker(slot: Int, building: VillageDetail.BuildingSlot?, queueEntry: VillageDetail.QueueEntry?, scale: CGFloat) -> some View {
        let isBuilt = building?.buildingKey != nil
        let isDamaged = (building?.hp ?? 100) < 100
        let iconSize: CGFloat = (slot == 8 ? 58 : 34) * scale

        return Button {
            tappedSlot = slot
        } label: {
            ZStack {
                if isBuilt, let gid = building?.gid {
                    Image("g\(gid)")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: iconSize, height: iconSize)
                } else {
                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 34 * scale, height: 34 * scale)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.5 * scale, dash: [3 * scale, 2 * scale]))
                        )
                    Text("+")
                        .font(.system(size: 18 * scale, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }

                if let queueEntry {
                    ConstructionBadge(entry: queueEntry, scale: scale)
                        .offset(y: iconSize / 2 + 12 * scale)
                } else if isBuilt, let level = building?.level {
                    Text("\(level)")
                        .font(.system(size: 10 * scale, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4 * scale)
                        .padding(.vertical, 1 * scale)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Capsule())
                        .offset(y: iconSize / 2 + 5 * scale)
                }

                if isDamaged {
                    Text("⚠️")
                        .font(.system(size: 12 * scale))
                        .offset(x: iconSize / 2 - 2 * scale, y: -(iconSize / 2 - 2 * scale))
                }
            }
            .shadow(color: .black.opacity(0.5), radius: 2 * scale)
            .overlay(
                Circle()
                    .stroke(Color.red.opacity(0.85), lineWidth: 2 * scale)
                    .frame(width: iconSize + 8 * scale, height: iconSize + 8 * scale)
                    .opacity(isDamaged ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Экран ошибки

    private func errorStateView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("Не удалось загрузить деревню")
                .font(.headline)
                .foregroundStyle(GameTheme.textPrimary)
            Text(message)
                .font(.footnote)
                .foregroundStyle(GameTheme.textMuted)
                .multilineTextAlignment(.center)
            Button("Повторить") {
                if let id = selectedVillageID {
                    Task { await villageSession.loadDetail(id: id, session) }
                } else {
                    Task { await villageSession.loadVillages(session) }
                }
            }
            .buttonStyle(.gamePrimary)
            .frame(width: 160)
        }
        .padding(32)
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 32)
    }

    // MARK: - Переименование

    private func performRename() async {
        guard let token = session.bearerToken else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let villageID = selectedVillageID else { return }
        renameError = nil
        isRenameSaving = true
        defer { isRenameSaving = false }
        do {
            try await APIClient.shared.renameVillage(id: villageID, name: trimmed, token: token)
            isRenaming = false
            villageSession.refreshSelected(session)
        } catch {
            session.signOutIfUnauthorized(error)
            renameError = (error as? LocalizedError)?.errorDescription ?? "Не удалось переименовать деревню."
        }
    }
}

// MARK: - Вспомогательные типы

struct IdentifiableSlotID: Identifiable { let id: Int }

struct ConstructionBadge: View {
    let entry: VillageDetail.QueueEntry
    var scale: CGFloat = 1

    private static let formatter = ISO8601DateFormatter()

    var body: some View {
        let started = Self.formatter.date(from: entry.startedAt) ?? .now
        let finishes = Self.formatter.date(from: entry.finishesAt) ?? .now

        TimelineView(.periodic(from: .now, by: 1)) { context in
            let span = finishes.timeIntervalSince(started)
            let elapsed = context.date.timeIntervalSince(started)
            let percent = span > 0 ? min(1, max(0, elapsed / span)) : 1
            let remaining = max(0, finishes.timeIntervalSince(context.date))

            VStack(spacing: 2 * scale) {
                Text("🔨").font(.system(size: 10 * scale))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.55)).frame(width: 30 * scale, height: 4 * scale)
                    Capsule()
                        .fill(LinearGradient(colors: [Color(red: 0.63, green: 0.9, blue: 0.29), Color(red: 0.13, green: 0.77, blue: 0.37)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 30 * scale * percent, height: 4 * scale)
                }
                Text(Self.remainingLabel(remaining))
                    .font(.system(size: 8 * scale, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 1)
            }
        }
    }

    private static func remainingLabel(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

// MARK: - SlotActionSheet / BuildingDetailCard

private struct SlotActionSheet: View {
    @EnvironmentObject private var session: AuthSession
    @Environment(\.dismiss) private var dismiss

    let villageID: Int
    let slot: Int
    let builtSlot: VillageDetail.BuildingSlot?
    let village: VillageDetail.VillageInfo
    let onChanged: () -> Void

    @State private var detail: SlotDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var selectedKey: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(builtSlot?.buildingKey != nil ? (builtSlot?.label ?? "Здание") : "Участок №\(slot)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }
                }
                .task { await load() }
                .gameScreenBackground()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Загрузка…").tint(GameTheme.amber).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 10) {
                Text(errorMessage).foregroundStyle(GameTheme.textMuted).multilineTextAlignment(.center)
                Button("Повторить") { Task { await load() } }.buttonStyle(.gameSecondary).frame(width: 140)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let detail {
            if let key = builtSlot?.buildingKey ?? selectedKey, let candidate = detail.catalogue.first(where: { $0.key == key }) {
                ScrollView {
                    BuildingDetailCard(
                        candidate: candidate,
                        village: village,
                        queueFull: detail.queueFull,
                        crystals: session.currentUser?.gold ?? 0,
                        isBusy: isBusy,
                        onBack: builtSlot?.buildingKey == nil ? { selectedKey = nil } : nil,
                        onAction: { instant in await performAction(buildingKey: candidate.key, instant: instant) }
                    )
                    .padding(16)
                }
            } else {
                buildPicker(detail)
            }
        }
    }

    private func buildPicker(_ detail: SlotDetail) -> some View {
        let buildable = detail.catalogue.filter { $0.requirementsMet && !$0.alreadyBuiltElsewhere }

        return ScrollView {
            if buildable.isEmpty {
                Text("Здесь пока нечего строить.")
                    .foregroundStyle(GameTheme.textMuted)
                    .padding(32)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 14) {
                    ForEach(buildable) { candidate in
                        Button { selectedKey = candidate.key } label: {
                            VStack(spacing: 4) {
                                Image("g\(candidate.gid)")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 34, height: 34)
                                Text(candidate.label)
                                    .font(.system(size: 11))
                                    .foregroundStyle(GameTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(GameTheme.panelTop.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }

    private func load() async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            detail = try await APIClient.shared.fetchVillageSlot(villageID: villageID, slot: slot, token: token)
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Неизвестная ошибка."
        }
        isLoading = false
    }

    private func performAction(buildingKey: String, instant: Bool) async {
        guard let token = session.bearerToken else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.performSlotAction(villageID: villageID, slot: slot, buildingKey: buildingKey, instant: instant, token: token)
            onChanged()
            dismiss()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Неизвестная ошибка."
        }
    }
}

private struct BuildingDetailCard: View {
    let candidate: BuildingCandidate
    let village: VillageDetail.VillageInfo
    let queueFull: Bool
    let crystals: Int
    let isBusy: Bool
    let onBack: (() -> Void)?
    let onAction: (Bool) async -> Void

    private var isMaxed: Bool { candidate.currentLevel >= candidate.maxLevel }
    private var isNew: Bool { candidate.currentLevel == 0 }

    private var have: [String: Int] { ["wood": village.wood, "clay": village.clay, "iron": village.iron, "crop": village.crop] }

    private var canAffordCost: Bool {
        guard let cost = candidate.nextCost else { return false }
        return village.wood >= cost.wood && village.clay >= cost.clay && village.iron >= cost.iron && village.crop >= cost.crop
    }

    private var requirementsOk: Bool { candidate.requires.allSatisfy(\.met) }

    private var canUpgrade: Bool {
        !isBusy && !isMaxed && !queueFull && canAffordCost && requirementsOk
    }

    private var canFinishInstant: Bool {
        canUpgrade && crystals >= (candidate.instantFinishCost ?? Int.max)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    Label("Назад", systemImage: "chevron.left").font(.footnote)
                }
                .buttonStyle(.plain)
                .foregroundStyle(GameTheme.textMuted)
            }

            HStack(spacing: 10) {
                Image("g\(candidate.gid)").resizable().aspectRatio(contentMode: .fit).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.label).font(.headline).foregroundStyle(GameTheme.textPrimary)
                    if let effect = candidate.effect, !effect.isEmpty {
                        Text(effect).font(.caption).foregroundStyle(GameTheme.amber)
                    }
                }
            }

            if let description = candidate.description, !description.isEmpty {
                Text(description).font(.footnote).foregroundStyle(GameTheme.textSecondary)
            }

            Text(isMaxed ? "Достигнут максимальный уровень" : "Уровень \(candidate.currentLevel) → \(candidate.currentLevel + 1)")
                .font(.subheadline.bold())
                .foregroundStyle(GameTheme.amber)

            if !isMaxed {
                if let bonus = candidate.bonusNext ?? candidate.bonusCurrent {
                    boxSection(title: "Бонус") {
                        HStack {
                            Text(bonus.label).foregroundStyle(GameTheme.textPrimary)
                            Spacer()
                            if let current = candidate.bonusCurrent {
                                Text("\(current.value)\(current.suffix)").foregroundStyle(GameTheme.textPrimary)
                                if candidate.bonusNext != nil {
                                    Text(" → \(bonus.value)\(bonus.suffix)").foregroundStyle(GameTheme.good)
                                }
                            } else {
                                Text("\(bonus.value)\(bonus.suffix)").foregroundStyle(GameTheme.textPrimary)
                            }
                        }
                        .font(.footnote)
                    }
                }

                if !candidate.requires.isEmpty {
                    boxSection(title: "Требуется") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(candidate.requires) { req in
                                HStack {
                                    Text("\(req.met ? "✓" : "✕") \(req.label) ур.\(req.level)")
                                        .foregroundStyle(req.met ? GameTheme.good : GameTheme.bad)
                                    Spacer()
                                }
                                .font(.footnote)
                            }
                        }
                    }
                }

                if let cost = candidate.nextCost {
                    boxSection(title: "Стоимость") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 14) {
                                costItem(icon: "🌲", need: cost.wood, have: have["wood"] ?? 0)
                                costItem(icon: "🧱", need: cost.clay, have: have["clay"] ?? 0)
                                costItem(icon: "⛏️", need: cost.iron, have: have["iron"] ?? 0)
                                costItem(icon: "🌾", need: cost.crop, have: have["crop"] ?? 0)
                            }
                            if let time = candidate.nextTime {
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

                HStack(spacing: 10) {
                    Button {
                        Task { await onAction(true) }
                    } label: {
                        Text("Завершить\(candidate.instantFinishCost.map { " (\($0)💎)" } ?? "")")
                    }
                    .buttonStyle(.gameSecondary)
                    .disabled(!canFinishInstant)

                    Button {
                        Task { await onAction(false) }
                    } label: {
                        Text(isNew ? "Построить" : "Улучшить")
                    }
                    .buttonStyle(.gamePrimary)
                    .disabled(!canUpgrade)
                }
            }
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