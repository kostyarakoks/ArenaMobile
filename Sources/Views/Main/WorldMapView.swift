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
struct WorldMapView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var mapData: WorldMapResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var goToXText = "0"
    @State private var goToYText = "0"

    @State private var selectedTile: WorldMapTile?
    @State private var preview: PublicVillage?
    @State private var previewLoading = false

    private let tileSize: CGFloat = 26

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                goToBar

                content

                if let mapData {
                    legend
                    if !mapData.myVillages.isEmpty {
                        myVillagesList(mapData.myVillages)
                    }
                }

                if let selectedTile {
                    detailsPanel(selectedTile)
                }
            }
            .padding(.vertical, 12)
        }
        .gameScreenBackground()
        .navigationTitle("Карта")
        .task {
            guard mapData == nil else { return }
            await load(x: 0, y: 0)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && mapData == nil {
            ProgressView("Загрузка карты…")
                .frame(maxWidth: .infinity, minHeight: 220)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить карту").font(.headline)
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Повторить") {
                    Task { await load(x: mapData?.center.x ?? 0, y: mapData?.center.y ?? 0) }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        } else if let mapData {
            gridView(mapData)
        }
    }

    // MARK: - Go-to bar

    private var goToBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("X").font(.caption).foregroundStyle(GameTheme.textSecondary)
                TextField("0", text: $goToXText)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                Text("Y").font(.caption).foregroundStyle(GameTheme.textSecondary)
                TextField("0", text: $goToYText)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                Button("Перейти") {
                    Task { await load(x: Int(goToXText) ?? 0, y: Int(goToYText) ?? 0) }
                }
                .buttonStyle(.gamePrimary)
                .fixedSize()
                Button("Центр") {
                    Task { await load(x: 0, y: 0) }
                }
                .buttonStyle(.gameSecondary)
                .fixedSize()
            }
            if let mapData {
                Text("Радиус обзора вокруг ваших деревень: \(mapData.visionRadius)")
                    .font(.caption2)
                    .foregroundStyle(GameTheme.textMuted)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Grid

    private func gridView(_ mapData: WorldMapResponse) -> some View {
        let width = mapData.bounds.maxX - mapData.bounds.minX + 1
        var rows: [[WorldMapTile]] = []
        var i = 0
        while i < mapData.tiles.count {
            rows.append(Array(mapData.tiles[i..<min(i + width, mapData.tiles.count)]))
            i += width
        }

        return VStack(spacing: 12) {
            panControls(mapData)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 1) {
                    ForEach(rows.indices, id: \.self) { r in
                        HStack(spacing: 1) {
                            ForEach(rows[r]) { tile in
                                tileView(tile)
                            }
                        }
                    }
                }
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(1)
            }
        }
    }

    private func panControls(_ mapData: WorldMapResponse) -> some View {
        VStack(spacing: 4) {
            panButton("chevron.up") { await load(x: mapData.center.x, y: mapData.center.y + mapData.gridSize) }
            HStack {
                panButton("chevron.left") { await load(x: mapData.center.x - mapData.gridSize, y: mapData.center.y) }
                Spacer()
                Text("(\(mapData.center.x)|\(mapData.center.y))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(GameTheme.textSecondary)
                Spacer()
                panButton("chevron.right") { await load(x: mapData.center.x + mapData.gridSize, y: mapData.center.y) }
            }
            panButton("chevron.down") { await load(x: mapData.center.x, y: mapData.center.y - mapData.gridSize) }
        }
        .padding(.horizontal, 40)
    }

    private func panButton(_ systemImage: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: systemImage)
                .frame(width: 32, height: 24)
        }
        .buttonStyle(.bordered)
    }

    private func tileView(_ tile: WorldMapTile) -> some View {
        let isSelected = selectedTile?.x == tile.x && selectedTile?.y == tile.y
        let kind = tile.foggy || tile.village != nil ? nil : WorldMapTerrain.kind(x: tile.x, y: tile.y)

        return Button {
            selectedTile = tile
            preview = nil
        } label: {
            ZStack {
                tileBackground(tile, kind: kind)
                tileContent(tile, kind: kind)
            }
            .frame(width: tileSize, height: tileSize)
            .overlay(
                Rectangle().stroke(isSelected ? Color.yellow : Color.black.opacity(0.15), lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tileBackground(_ tile: WorldMapTile, kind: WorldMapTerrain.Kind?) -> some View {
        if tile.foggy {
            RadialGradient(
                colors: [Color.white.opacity(0.12), Color(red: 0.06, green: 0.09, blue: 0.15)],
                center: .center, startRadius: 0, endRadius: tileSize
            )
        } else if let village = tile.village {
            (village.isMine ? Color(red: 0.56, green: 0.82, blue: 0.48)
                : village.isAlly ? Color(red: 0.56, green: 0.79, blue: 0.93)
                : Color(red: 0.9, green: 0.6, blue: 0.6))
        } else {
            WorldMapTerrain.color(for: kind ?? .grass)
        }
    }

    @ViewBuilder
    private func tileContent(_ tile: WorldMapTile, kind: WorldMapTerrain.Kind?) -> some View {
        if let village = tile.village {
            Text(village.isCapital ? "★" : "⌂")
                .font(.system(size: 11))
                .foregroundStyle(.white)
        } else if !tile.foggy, let kind, let icon = WorldMapTerrain.icon(for: kind) {
            Text(icon).font(.system(size: 10))
        }
    }

    // MARK: - Legend / lists

    private var legend: some View {
        HStack(spacing: 10) {
            legendItem(color: Color(red: 0.56, green: 0.82, blue: 0.48), label: "Мои")
            legendItem(color: Color(red: 0.56, green: 0.79, blue: 0.93), label: "Союзники")
            legendItem(color: Color(red: 0.9, green: 0.6, blue: 0.6), label: "Другие")
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
                    Task { await load(x: v.x, y: v.y) }
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
        .padding(.horizontal)
    }

    // MARK: - Selected-tile details

    @ViewBuilder
    private func detailsPanel(_ tile: WorldMapTile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .gamePanel()
        .padding(.horizontal)
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
