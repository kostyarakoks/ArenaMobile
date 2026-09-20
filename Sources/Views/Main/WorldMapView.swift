import SwiftUI

/// The "Карта" tab's real content — replaces the generic placeholder for this nav item (see
/// NavDestinationView.swift). Renders a window of the world map from Api\MapController (GET
/// /api/map) with the same "fog of war" the web app's own Map/Index.vue shows (see
/// App\Services\WorldMapService's docblock): every tile within `vision_radius` of any of the
/// player's own villages is drawn normally; everything else comes back from the server as a
/// bare {x,y,foggy:true} — nothing about it is known, so it's drawn as plain mist, never a
/// guess. Tapping a visible village fetches its public building layout (GET
/// /api/map/villages/{id}) — read-only "scouting" from outside, no resources/hp, mirroring the
/// web side's own tap-to-preview panel.
///
/// Rewritten from a static button-grid-in-a-ScrollView (no zoom, tap-arrows to pan, a permanent
/// coordinate-entry bar and a legend/village-list stacked below the grid) into a full-bleed,
/// pinch-zoom + free-pan canvas — per the reference video the user supplied of another mobile
/// strategy game's world map: a continuous painted map you pinch/drag around, with base icons
/// sitting directly on the terrain and a minimal floating HUD (search, a "distance to home"
/// return button, edge arrows right on the map itself) instead of a scrolling stack of controls
/// competing with the map for vertical space. Shares ZoomableMapContainer with VillageMapView
/// (pulled out into its own file this round) so both maps pinch/pan identically.
struct WorldMapView: View {
    @EnvironmentObject private var session: AuthSession
    @EnvironmentObject private var villageSession: VillageSession

    // Called instead of opening the tile-details panel when the tapped tile is one of YOUR OWN
    // villages — jumps straight into it, mirroring the web map's own onMapClick shortcut
    // (tile.village?.is_mine -> router.visit(route('village.buildings', ...))). Defaults to a
    // no-op so #Preview and any other caller that doesn't care still compiles.
    var onOwnVillageSelected: () -> Void = {}

    // Same as VillageMapView's own `selectItem` — see MapOverlayControls' doc comment for why
    // this replaced a NavigationLink push.
    var selectItem: (NavItem) -> Void = { _ in }

    @State private var mapData: WorldMapResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var goToXText = "0"
    @State private var goToYText = "0"
    @State private var showSearch = false

    @State private var selectedTile: WorldMapTile?
    @State private var preview: PublicVillage?
    @State private var previewLoading = false

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gameScreenBackground()
        // No system nav title any more — the global resources header (GameHeaderBar, wired up
        // in MainTabView) is the only top chrome now, same "нет отдельного заголовка, просто
        // карта" shape the web version's Map/Index.vue has under GameLayout.
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .trailing) {
            MapOverlayControls(selectItem: selectItem)
                .padding(.trailing, 12)
        }
        .overlay(alignment: .bottomLeading) {
            if mapData != nil {
                hudButton(systemImage: "magnifyingglass") { showSearch = true }
                    .padding(.leading, 14)
                    .padding(.bottom, 14)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let mapData {
                homeBadge(mapData)
                    .padding(.trailing, 14)
                    .padding(.bottom, 14)
            }
        }
        .sheet(isPresented: $showSearch) { searchSheet }
        .sheet(item: $selectedTile) { tile in
            detailsSheet(tile)
        }
        .task {
            guard mapData == nil else { return }
            // Open centred on the player's own village, not world (0|0) — mirrors the web
            // version's "Мой город" jump, just applied automatically as the map's first paint
            // instead of needing a manual tap (see Map/Index.vue's goToCapital). Falls back to
            // (0|0) only if no village has loaded yet (e.g. this tab was opened before
            // VillageSession's own initial fetch resolved).
            await villageSession.loadIfNeeded(session)
            let home = villageSession.selectedVillage ?? villageSession.villages.first
            await load(x: home?.x ?? 0, y: home?.y ?? 0)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && mapData == nil {
            ProgressView("Загрузка карты…")
                .tint(GameTheme.amber)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить карту").font(.headline).foregroundStyle(GameTheme.textPrimary)
                Text(errorMessage).font(.footnote).foregroundStyle(GameTheme.textMuted).multilineTextAlignment(.center)
                Button("Повторить") {
                    Task { await load(x: mapData?.center.x ?? 0, y: mapData?.center.y ?? 0) }
                }
                .buttonStyle(.gamePrimary)
                .frame(width: 160)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let mapData {
            mapCanvas(mapData)
        }
    }

    // MARK: - Canvas

    // Continuous pinch-zoom + pan canvas (ZoomableMapContainer, shared with VillageMapView) —
    // tiles are absolutely positioned inside one big GeometryReader-sized surface rather than
    // laid out in a grid of stacked rows, so the map reads as one seamless painted area (edge to
    // edge, no gaps) instead of a spreadsheet of boxed cells, matching the reference video.
    private func mapCanvas(_ mapData: WorldMapResponse) -> some View {
        let width = mapData.bounds.maxX - mapData.bounds.minX + 1
        let height = mapData.bounds.maxY - mapData.bounds.minY + 1

        return ZoomableMapContainer(minZoom: 1, maxZoom: 4) {
            GeometryReader { geo in
                let cellW = geo.size.width / CGFloat(width)
                let cellH = geo.size.height / CGFloat(height)

                ZStack(alignment: .topLeading) {
                    ForEach(mapData.tiles) { tile in
                        tileView(tile, cellW: cellW, cellH: cellH)
                            .frame(width: cellW, height: cellH)
                            .position(
                                x: CGFloat(tile.x - mapData.bounds.minX) * cellW + cellW / 2,
                                y: CGFloat(mapData.bounds.maxY - tile.y) * cellH + cellH / 2
                            )
                    }
                }
            }
        }
        .overlay(alignment: .top) { edgeArrow(systemImage: "chevron.up") { await load(x: mapData.center.x, y: mapData.center.y + mapData.gridSize) } }
        .overlay(alignment: .bottom) { edgeArrow(systemImage: "chevron.down") { await load(x: mapData.center.x, y: mapData.center.y - mapData.gridSize) } }
        .overlay(alignment: .leading) { edgeArrow(systemImage: "chevron.left") { await load(x: mapData.center.x - mapData.gridSize, y: mapData.center.y) } }
        .overlay(alignment: .trailing) { edgeArrow(systemImage: "chevron.right") { await load(x: mapData.center.x + mapData.gridSize, y: mapData.center.y) } }
    }

    // Small floating chevron sitting right on the map's own edge — same idea as the reference
    // video's single translucent arrow poking in from the side (not a labelled control bar
    // underneath the map). Tapping one loads the next window in that direction, one gridSize
    // step over, the same jump the old panControls buttons made.
    private func edgeArrow(systemImage: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.4))
                .clipShape(Circle())
        }
        .padding(6)
    }

    @ViewBuilder
    private func tileView(_ tile: WorldMapTile, cellW: CGFloat, cellH: CGFloat) -> some View {
        let isSelected = selectedTile?.x == tile.x && selectedTile?.y == tile.y
        let kind = tile.foggy || tile.village != nil ? nil : WorldMapTerrain.kind(x: tile.x, y: tile.y)
        let minCell = min(cellW, cellH)

        Button {
            // Tapping one of YOUR OWN villages jumps straight into it — nothing to "scout" about
            // a village you already own, so skip the details panel entirely (see
            // onOwnVillageSelected's own doc comment above). Every other tile (someone else's
            // village, an empty plot, fog) still opens the details sheet as before.
            if let village = tile.village, village.isMine {
                villageSession.selectVillage(id: village.id, session)
                onOwnVillageSelected()
                return
            }
            selectedTile = tile
            preview = nil
        } label: {
            ZStack {
                tileBackground(tile, kind: kind)
                if let village = tile.village {
                    villageMarker(village, size: minCell)
                } else if !tile.foggy, let kind, let icon = WorldMapTerrain.icon(for: kind) {
                    Text(icon).font(.system(size: minCell * 0.4))
                }
            }
            .overlay(
                Rectangle().stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // Edge-to-edge terrain fill (no per-tile border/gap) so the whole window reads as one
    // continuous painted map instead of a grid of boxed squares — the biggest single visual gap
    // vs the reference video the old implementation had.
    @ViewBuilder
    private func tileBackground(_ tile: WorldMapTile, kind: WorldMapTerrain.Kind?) -> some View {
        if tile.foggy {
            RadialGradient(
                colors: [Color.white.opacity(0.12), Color(red: 0.06, green: 0.09, blue: 0.15)],
                center: .center, startRadius: 0, endRadius: 60
            )
        } else if tile.village != nil {
            WorldMapTerrain.color(for: .grass)
        } else {
            WorldMapTerrain.color(for: kind ?? .grass)
        }
    }

    // Every base — yours, an ally's, anyone else's — uses the same painted castle art (see
    // icon_village, Assets.xcassets/GameAssets/UI) with a coloured ring behind it for
    // ownership, plus a name tag underneath: the reference video's own "one base icon, an
    // alliance-coloured chip, a name label" look, rather than the old plain star/house glyph.
    private func villageMarker(_ village: TileVillage, size: CGFloat) -> some View {
        let tint: Color = village.isMine ? Color(red: 0.42, green: 0.82, blue: 0.4)
            : village.isAlly ? Color(red: 0.4, green: 0.68, blue: 0.95)
            : Color(red: 0.9, green: 0.38, blue: 0.38)

        return VStack(spacing: 1) {
            ZStack {
                Circle().fill(tint.opacity(0.35)).frame(width: size * 0.92, height: size * 0.92)
                Circle().stroke(tint, lineWidth: 1.5).frame(width: size * 0.92, height: size * 0.92)
                Image("icon_village")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.68, height: size * 0.68)
                if village.isCapital {
                    Text("★")
                        .font(.system(size: max(8, size * 0.24), weight: .bold))
                        .foregroundStyle(GameTheme.amber)
                        .offset(x: size * 0.32, y: -size * 0.32)
                        .shadow(color: .black.opacity(0.6), radius: 1)
                }
            }
            Text(village.name)
                .font(.system(size: max(7, size * 0.2), weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.8), radius: 1)
                .lineLimit(1)
                .frame(maxWidth: size * 1.8)
        }
    }

    // MARK: - Floating HUD

    private func hudButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .gameOctagonBadge(cut: 9)
        }
    }

    // "Return home" badge, bottom-right — same spot and purpose as the reference video's own
    // circular "▲ 788km" indicator: shows how far the currently-loaded window's centre is from
    // your nearest village, tap to jump straight back. Distance is in TILES, not real-world
    // km (this game has no such unit) — shown as "N поля" the same way the rest of the app
    // already talks about map distance (coordinates, not a fake distance unit).
    @ViewBuilder
    private func homeBadge(_ mapData: WorldMapResponse) -> some View {
        if let home = nearestOwnVillage(mapData) {
            let dx = home.x - mapData.center.x
            let dy = home.y - mapData.center.y
            let distance = max(abs(dx), abs(dy)) // Chebyshev — matches this game's square grid movement, not a straight-line radius
            if distance > 0 {
                Button {
                    Task { await load(x: home.x, y: home.y) }
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: "house.fill").font(.system(size: 14))
                        Text("\(distance)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .gameOctagonBadge(cut: 10)
                }
            }
        }
    }

    private func nearestOwnVillage(_ mapData: WorldMapResponse) -> VillageSummary? {
        mapData.myVillages.min { a, b in
            let da = max(abs(a.x - mapData.center.x), abs(a.y - mapData.center.y))
            let db = max(abs(b.x - mapData.center.x), abs(b.y - mapData.center.y))
            return da < db
        }
    }

    // MARK: - Search sheet (coordinate jump + legend + village list — everything that used to
    // sit permanently on screen above/below the map now lives behind the magnifier button
    // instead, so the map itself gets the full screen, same as the reference video).

    private var searchSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Text("X").font(.caption).foregroundStyle(GameTheme.textSecondary)
                        TextField("0", text: $goToXText)
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                        Text("Y").font(.caption).foregroundStyle(GameTheme.textSecondary)
                        TextField("0", text: $goToYText)
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                        Button("Перейти") {
                            Task {
                                await load(x: Int(goToXText) ?? 0, y: Int(goToYText) ?? 0)
                                showSearch = false
                            }
                        }
                        .buttonStyle(.gamePrimary)
                        .fixedSize()
                    }

                    Button("В центр мира (0|0)") {
                        Task { await load(x: 0, y: 0); showSearch = false }
                    }
                    .buttonStyle(.gameSecondary)

                    if let mapData {
                        legend
                        if !mapData.myVillages.isEmpty {
                            myVillagesList(mapData.myVillages)
                        }
                    }
                }
                .padding(16)
            }
            .gameScreenBackground()
            .navigationTitle("Поиск на карте")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { showSearch = false } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var legend: some View {
        HStack(spacing: 10) {
            legendItem(color: Color(red: 0.42, green: 0.82, blue: 0.4), label: "Мои")
            legendItem(color: Color(red: 0.4, green: 0.68, blue: 0.95), label: "Союзники")
            legendItem(color: Color(red: 0.9, green: 0.38, blue: 0.38), label: "Другие")
            legendItem(color: Color(red: 0.06, green: 0.09, blue: 0.15), label: "Туман")
        }
        .font(.caption2)
        .foregroundStyle(GameTheme.textMuted)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label)
        }
    }

    private func myVillagesList(_ villages: [VillageSummary]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Мои деревни").font(.caption.bold()).foregroundStyle(GameTheme.amber)
            ForEach(villages) { v in
                Button {
                    Task { await load(x: v.x, y: v.y); showSearch = false }
                } label: {
                    HStack {
                        Text(v.name + (v.isCapital ? " ★" : "")).foregroundStyle(GameTheme.textPrimary)
                        Spacer()
                        Text("(\(v.x)|\(v.y))").foregroundStyle(GameTheme.textSecondary)
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gamePanel()
    }

    // MARK: - Selected-tile details (now a bottom sheet instead of an inline card, so it never
    // competes with the map for space)

    private func detailsSheet(_ tile: WorldMapTile) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if tile.foggy {
                        Text("Туман войны").font(.subheadline.bold()).foregroundStyle(GameTheme.amber)
                        if let mapData {
                            Text("Этот участок вне поля зрения ваших деревень (радиус обзора — \(mapData.visionRadius)). Постройте или отвоюйте деревню ближе, чтобы его открыть.")
                                .font(.caption)
                                .foregroundStyle(GameTheme.textSecondary)
                        }
                    } else if let village = tile.village {
                        Text(village.name).font(.subheadline.bold()).foregroundStyle(GameTheme.amber)
                        Text("(\(village.x)|\(village.y)) · \(village.owner)").font(.caption).foregroundStyle(GameTheme.textSecondary)
                        if let allianceTag = village.allianceTag {
                            Text("[\(allianceTag)]").font(.caption2).foregroundStyle(GameTheme.textMuted)
                        }
                        Text("Население: \(village.population)").font(.caption).foregroundStyle(GameTheme.textPrimary)

                        if previewLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else if let preview {
                            buildingsGrid(preview)
                        } else {
                            Button("Посмотреть постройки") {
                                Task { await loadPreview(id: village.id) }
                            }
                            .buttonStyle(.gameSecondary)
                            .fixedSize()
                        }
                    } else {
                        Text("Свободный участок").font(.subheadline).foregroundStyle(GameTheme.textPrimary)
                        Text("(\(tile.x)|\(tile.y))").font(.caption).foregroundStyle(GameTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .gameScreenBackground()
            .navigationTitle(tile.village?.name ?? "Участок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { selectedTile = nil } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func buildingsGrid(_ preview: PublicVillage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Застроено \(preview.builtPlots) из \(preview.totalPlots) участков")
                .font(.caption2)
                .foregroundStyle(GameTheme.textMuted)

            if preview.buildings.isEmpty {
                Text("На этом участке ещё ничего не построено.")
                    .font(.caption)
                    .foregroundStyle(GameTheme.textSecondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                    ForEach(preview.buildings) { b in
                        VStack(spacing: 2) {
                            AsyncImage(url: buildingIconURL(gid: b.gid)) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().aspectRatio(contentMode: .fit)
                                } else {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.15))
                                }
                            }
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            Text("\(b.level)").font(.system(size: 9)).foregroundStyle(GameTheme.textMuted)
                        }
                    }
                }
            }
        }
    }

    private func buildingIconURL(gid: Int?) -> URL? {
        guard let gid else { return nil }
        return URL(string: "/game-assets/img/g/g\(gid).gif", relativeTo: APIClient.shared.baseURL)?.absoluteURL
    }

    // MARK: - Networking

    private func load(x: Int, y: Int) async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        selectedTile = nil
        preview = nil
        do {
            mapData = try await APIClient.shared.fetchWorldMap(centerX: x, centerY: y, token: token)
            goToXText = "\(x)"
            goToYText = "\(y)"
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Неизвестная ошибка."
        }
        isLoading = false
    }

    private func loadPreview(id: Int) async {
        guard let token = session.bearerToken else { return }
        previewLoading = true
        do {
            preview = try await APIClient.shared.fetchPublicVillage(id: id, token: token)
        } catch {
            session.signOutIfUnauthorized(error)
        }
        previewLoading = false
    }
}
