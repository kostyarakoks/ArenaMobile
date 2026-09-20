import SwiftUI

/// The "Город" tab's real content — the native counterpart of Village/Buildings.vue (dorf2):
/// loads the player's village list + one village's building-plot map from
/// Api\VillageController (travianz-laravel), and draws/behaves like the web version as closely
/// as a native screen reasonably can:
///  - background art + 21 plot markers, positioned from an admin map template or the built-in
///    classic layout (VillageLayout.swift), main building (slot 8) drawn larger with a warm
///    glow behind it, damaged plots ringed in red (siege damage);
///  - the village's tier badge (Поселение/Деревня/Город/Мегаполис) top-left, same as the web;
///  - a live construction-progress bar + countdown on any plot with a queued build (mirrors
///    ConstructionProgress.vue), ticking from the server's real started_at/finishes_at window;
///  - tapping a plot opens a bottom sheet that merges BuildingActionMenu + UpgradeModal (built
///    plot) or EmptyPlotOverlay + UpgradeModal (empty plot) into one flow — a single tap being
///    the natural mobile equivalent of the web's hover-then-click sequence — with real
///    build/upgrade actions (Api\VillageController::slotAction(), same BuildingService the web
///    app uses) including "finish instantly for 💎";
///  - pinch-to-zoom + pan on the map itself (native equivalent of ZoomableMap.vue).
struct VillageMapView: View {
    @EnvironmentObject private var session: AuthSession
    // Active-village state lives here now (see VillageSession.swift) — shared with the global
    // header (GameHeaderBar) and the floating map controls (MapOverlayControls) instead of this
    // screen owning its own private copy.
    @EnvironmentObject private var villageSession: VillageSession

    // Threaded down from NavDestinationView's own `selectItem` (via MainTabView) so
    // MapOverlayControls can switch the active tab through the app's one navigation mechanism
    // instead of pushing onto the NavigationStack — see MapOverlayControls' doc comment.
    var selectItem: (NavItem) -> Void = { _ in }

    @State private var tappedSlot: Int?
    // Throttles the construction-finished poll below — set to the moment a refresh was last
    // actually fired, not merely checked, so a slow/failed request gets retried a few seconds
    // later instead of being fired again every single tick of the 1s poll loop.
    @State private var lastConstructionRefreshAttempt: Date = .distantPast

    // Rename — "добавить возможность название деревни при достижение 2 уровня главного
    // здания (так же сделать в iOS)". Gated by detail.village.canRename (server-checked too,
    // see Api\VillageController::update()), so the pencil button below only appears once
    // that's true.
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var renameError: String?

    private static let queueDateFormatter = ISO8601DateFormatter()

    private var selectedVillageID: Int? { villageSession.selectedVillageID }
    private var detail: VillageDetail? { villageSession.detail }
    private var isLoading: Bool { villageSession.isLoading }
    private var errorMessage: String? { villageSession.errorMessage }

    var body: some View {
        content
            // The global resources header (GameHeaderBar, wired up in MainTabView) is the only
            // top chrome now — this screen no longer draws its own header (see
            // MapOverlayControls for where the village switcher and profile/messages/quests
            // shortcuts that used to live in that header moved to instead).
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .trailing) {
                MapOverlayControls(selectItem: selectItem)
                    .padding(.trailing, 12)
            }
            .task {
                await villageSession.loadIfNeeded(session)
            }
            // A finished build used to just sit there showing the construction badge forever:
            // `plotMarker` decides "under construction" purely from whether `detail.queue` still
            // contains an entry for that slot (see its own doc comment), and nothing ever told
            // the app to re-fetch `detail.queue` once a countdown reached zero — ConstructionBadge
            // is a pure renderer with no callback, and VillageSession.loadIfNeeded only fetches
            // once per signed-in session. This background poll is the missing piece: once a
            // second, check whether any queue entry's finishesAt has passed, and if so re-fetch
            // the village (the server will have already dropped/advanced that entry) — same
            // villageSession.refreshSelected(session) call SlotActionSheet's onChanged already
            // uses after a NEW build/upgrade action, just now also firing for one COMPLETING.
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard let queue = villageSession.detail?.queue, !queue.isEmpty else { continue }
                    let hasFinished = queue.contains { entry in
                        guard let finishes = Self.queueDateFormatter.date(from: entry.finishesAt) else { return false }
                        return finishes <= .now
                    }
                    // Re-checked every tick but only actually fires every few seconds — avoids
                    // hammering the server every second while waiting for a slow response, while
                    // still retrying if the first attempt was lost to a transient network error.
                    guard hasFinished, Date.now.timeIntervalSince(lastConstructionRefreshAttempt) > 3 else { continue }
                    lastConstructionRefreshAttempt = .now
                    villageSession.refreshSelected(session)
                }
            }
            .sheet(item: Binding(get: { tappedSlot.map { IdentifiableInt(id: $0) } }, set: { tappedSlot = $0?.id })) { wrapped in
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
            .alert("Переименовать деревню", isPresented: $isRenaming) {
                TextField("Название деревни", text: $renameText)
                Button("Сохранить") { Task { await performRename() } }
                Button("Отмена", role: .cancel) {}
            } message: {
                if let renameError {
                    Text(renameError)
                }
            }
    }

    private func performRename() async {
        guard let token = session.bearerToken else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let villageID = selectedVillageID else { return }
        do {
            try await APIClient.shared.renameVillage(id: villageID, name: trimmed, token: token)
            villageSession.refreshSelected(session)
        } catch {
            session.signOutIfUnauthorized(error)
            renameError = (error as? LocalizedError)?.errorDescription ?? "Не удалось переименовать деревню."
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && detail == nil {
            ProgressView("Загрузка деревни…")
                .tint(GameTheme.amber)
                .foregroundStyle(GameTheme.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gameScreenBackground()
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить деревню").font(.headline).foregroundStyle(GameTheme.textPrimary)
                Text(errorMessage).font(.footnote).foregroundStyle(GameTheme.textMuted).multilineTextAlignment(.center)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gameScreenBackground()
        } else if let detail {
            // Fills exactly the space between the nav bar and the bottom dock — no ScrollView,
            // no side padding, matching the web's own "карта занимает весь контейнер" layout
            // (Village/Buildings.vue's own height: calc(...) container).
            mapCanvas(detail)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gameScreenBackground()
        } else {
            Color.clear.gameScreenBackground()
        }
    }

    private func mapCanvas(_ detail: VillageDetail) -> some View {
        let width = Double(detail.map.viewboxWidth ?? Int(VillageLayout.viewboxWidth))
        let height = Double(detail.map.viewboxHeight ?? Int(VillageLayout.viewboxHeight))
        // Built with reduce(into:), not Dictionary(uniqueKeysWithValues:) — the latter traps at
        // runtime on a duplicate key, and both `coords` and `buildings` come straight off the
        // network, so a malformed/duplicate slot from the server should never crash the map.
        let coordsBySlot: [Int: (cx: Double, cy: Double)] = {
            if let serverCoords = detail.map.coords, !serverCoords.isEmpty {
                return serverCoords.reduce(into: [:]) { acc, c in acc[c.slot] = (cx: c.cx, cy: c.cy) }
            }
            return VillageLayout.coords
        }()
        let backgroundPath = detail.map.background ?? VillageLayout.backgroundPath(tribe: detail.tribe, wallLevel: detail.wallLevel)
        let buildingsBySlot: [Int: VillageDetail.BuildingSlot] = detail.buildings.reduce(into: [:]) { acc, b in acc[b.slot] = b }
        // First (earliest started_at) queue entry per slot — later chained entries for the same
        // slot are still waiting behind it, so only this one is "in progress" right now.
        let queueBySlot: [Int: VillageDetail.QueueEntry] = detail.queue.reduce(into: [:]) { acc, item in
            if let existing = acc[item.slot], existing.startedAt <= item.startedAt { return }
            acc[item.slot] = item
        }

        // contentAspect: fits the map to the container's HEIGHT and derives width from the
        // village layout's own viewbox ratio (same as ZoomableMap.vue's WORLD_W/WORLD_H camera)
        // instead of stretching to exactly fill the portrait screen on both axes — that stretch
        // was why the map read as "cropped to the screen, doesn't scroll left/right" (there was
        // nothing wider than the screen TO scroll to). See ZoomableMapContainer's own doc comment.
        return ZoomableMapContainer(contentAspect: CGFloat(width / height)) {
            // One GeometryReader for the whole canvas — its `geo.size` is the actual rendered
            // pixel size (which changes with pinch-zoom), so both the glow and the marker
            // positions scale off the SAME real size instead of the raw viewbox numbers.
            GeometryReader { geo in
                let scaleX = geo.size.width / width
                let scaleY = geo.size.height / height

                ZStack {
                    // No corner rounding/border here on purpose — the map now fills the screen
                    // edge to edge between the nav bar and the bottom dock ("карту на весь
                    // экран"), so a rounded card frame would just clip corners against the
                    // screen's own edges instead of reading as a card.
                    backgroundImage(path: backgroundPath)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()

                    // Warm glow behind the main building (slot 8, centred on the classic
                    // canvas) — same cosmetic touch Buildings.vue draws behind its own hub slot.
                    RadialGradient(
                        colors: [Color(red: 1, green: 0.77, blue: 0.42).opacity(0.35), Color(red: 1, green: 0.71, blue: 0.33).opacity(0)],
                        center: .center, startRadius: 1, endRadius: max(geo.size.width, geo.size.height) * 0.22
                    )
                    .frame(width: geo.size.width * 0.46, height: geo.size.height * 0.46)
                    .allowsHitTesting(false)

                    // Village tier badge (Поселение/Деревня/Город/Мегаполис).
                    if let tierLabel = detail.village.tierLabel, !tierLabel.isEmpty {
                        Text(tierLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(GameTheme.amberLight)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .position(x: 46, y: 16)
                    }

                    // Village name + rename pencil, right below the tier badge — see
                    // isRenaming's own doc comment.
                    HStack(spacing: 4) {
                        Text(detail.village.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                        if detail.village.canRename {
                            Button {
                                renameText = detail.village.name
                                renameError = nil
                                isRenaming = true
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(GameTheme.amberLight)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .position(x: 46, y: 40)

                    // scaleX and scaleY are mathematically equal here (ZoomableMapContainer's
                    // contentAspect keeps both axes multiplied by the very same effectiveZoom
                    // factor — see its own doc comment), so either would do; min() is just a
                    // defensive guard against the two drifting apart from float rounding, so a
                    // marker's own art never gets stretched non-uniformly.
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
    }

    // Local asset (bundled by build_ios_assets.py) when this is one of the 4 classic
    // backgrounds — instant, no network round-trip — falling back to AsyncImage only for an
    // admin-uploaded custom map template, which is arbitrary per-village server content the app
    // can't bundle ahead of time. See VillageLayout.backgroundAssetName for the mapping.
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

    // Real building art (bundled locally — Assets.xcassets/GameAssets/Buildings, same
    // g<gid>.gif files Buildings.vue draws on the web, converted to PNG by
    // build_ios_assets.py) instead of a plain colored-circle placeholder. The main building
    // (slot 8) renders larger, matching Buildings.vue's own bigger-slot-8 treatment; a plot
    // with a live queue entry shows a construction badge (hammer + progress bar + countdown)
    // instead of its level number.
    //
    // `scale` is mapCanvas's markerScale (how much bigger the map's rendered pixel size is than
    // its base/unzoomed size right now) — every size/offset/line-width constant below is
    // multiplied by it, mirroring how `.position(...)` already multiplies each marker's
    // COORDINATES by scaleX/scaleY. Without this, only marker POSITIONS grew with pinch-zoom
    // while each marker's own art stayed a fixed pixel size, so buildings visibly shrank relative
    // to the map the more you zoomed in (reported: "здания не увеличиваются").
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
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 27 * scale, height: 27 * scale)
                        .overlay(Circle().stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 1 * scale, dash: [3 * scale, 2 * scale])))
                    Text("+")
                        .font(.system(size: 14 * scale, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
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

}

// Not `private` — FieldsMapView.swift reuses both of these for its own tap-sheet/construction
// overlay instead of duplicating them.
struct IdentifiableInt: Identifiable { let id: Int }

/// Live progress bar + countdown for one in-progress build-queue item — ticks from the real
/// started_at/finishes_at window via TimelineView, matching ConstructionProgress.vue.
///
/// `scale` mirrors plotMarker's own zoom scale, so the badge grows/shrinks together with the
/// icon it hangs off of instead of staying a fixed size while everything around it zooms.
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

/// Merges BuildingActionMenu (built plot) + EmptyPlotOverlay (empty plot) + UpgradeModal (both)
/// into one bottom sheet: fetches the same "what can go here" catalogue the web app's popups
/// fetch, and — for a built plot, or once a candidate is picked on an empty one — shows the
/// full build/upgrade detail card with a real build/upgrade action.
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
            // Built plot: go straight to that building's own card (its key is already known).
            // Empty plot: show the icon grid until one candidate is picked.
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

/// The build/upgrade detail card itself — native port of UpgradeModal.vue's body (everything
/// below its header/close button, which the enclosing sheet's own navigation bar already
/// provides): level line, bonus box, requirements box, cost box with live have/need coloring,
/// and the two action buttons.
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
