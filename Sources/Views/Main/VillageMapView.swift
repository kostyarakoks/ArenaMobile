import SwiftUI

/// The "Деревня" tab's real content — replaces the old generic placeholder for this one nav
/// item (see NavDestinationView.swift). Loads the player's village list + one village's
/// building-plot map from Api\VillageController (travianz-laravel), and draws it the same way
/// Buildings.vue does on the web: background art from the server, 21 plot markers positioned
/// either from an admin map template or the built-in classic layout (VillageLayout.swift).
/// Read-only for now — tapping a plot shows its info, no build/upgrade actions yet (those need
/// their own API routes first; see the note atop Api\VillageController).
struct VillageMapView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var villages: [VillageSummary] = []
    @State private var selectedVillageID: Int?
    @State private var detail: VillageDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var tappedBuilding: VillageDetail.BuildingSlot?

    var body: some View {
        content
            .navigationTitle(detail?.village.name ?? "Деревня")
            .toolbar {
                if villages.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            ForEach(villages) { village in
                                Button {
                                    selectedVillageID = village.id
                                    Task { await loadDetail(id: village.id) }
                                } label: {
                                    HStack {
                                        Text(village.name)
                                        if village.id == selectedVillageID {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "list.bullet")
                        }
                    }
                }
            }
            .task {
                guard villages.isEmpty else { return }
                await loadVillages()
            }
            .refreshable {
                if let id = selectedVillageID { await loadDetail(id: id) }
            }
            .sheet(item: $tappedBuilding) { building in
                BuildingInfoSheet(building: building)
                    .presentationDetents([.fraction(0.35)])
            }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && detail == nil {
            ProgressView("Загрузка деревни…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить деревню").font(.headline)
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Повторить") {
                    Task {
                        if let id = selectedVillageID { await loadDetail(id: id) } else { await loadVillages() }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let detail {
            ScrollView {
                VStack(spacing: 16) {
                    resourceHeader(detail.village)
                    mapCanvas(detail)
                }
                .padding(.vertical, 12)
            }
        } else {
            Color.clear
        }
    }

    private func resourceHeader(_ info: VillageDetail.VillageInfo) -> some View {
        VStack(spacing: 6) {
            Text("(\(info.x)|\(info.y))\(info.isCapital ? " · столица" : "")")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 18) {
                resourceStat(icon: "🌲", value: info.wood)
                resourceStat(icon: "🧱", value: info.clay)
                resourceStat(icon: "⛏️", value: info.iron)
                resourceStat(icon: "🌾", value: info.crop)
                VStack(spacing: 0) {
                    Text("👥").font(.callout)
                    Text("\(info.population)").font(.caption.monospacedDigit())
                }
            }
        }
        .padding(.horizontal)
    }

    private func resourceStat(icon: String, value: Int) -> some View {
        VStack(spacing: 0) {
            Text(icon).font(.callout)
            Text("\(value)").font(.caption.monospacedDigit())
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

        return GeometryReader { geo in
            let scaleX = geo.size.width / width
            let scaleY = geo.size.height / height

            ZStack {
                backgroundImage(path: backgroundPath)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                ForEach(coordsBySlot.keys.sorted(), id: \.self) { slot in
                    if let coord = coordsBySlot[slot] {
                        plotMarker(slot: slot, building: buildingsBySlot[slot])
                            .position(x: coord.cx * scaleX, y: coord.cy * scaleY)
                    }
                }
            }
        }
        .aspectRatio(width / height, contentMode: .fit)
        .padding(.horizontal)
    }

    private func backgroundImage(path: String) -> some View {
        let url = URL(string: path, relativeTo: APIClient.shared.baseURL)?.absoluteURL
        return AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                Color(red: 19 / 255, green: 42 / 255, blue: 77 / 255)
            }
        }
    }

    private func plotMarker(slot: Int, building: VillageDetail.BuildingSlot?) -> some View {
        let level = building?.buildingKey != nil ? building?.level : nil
        let isDamaged = (building?.hp ?? 100) < 100

        return Button {
            tappedBuilding = building ?? VillageDetail.BuildingSlot(slot: slot, buildingKey: nil, level: 0, label: "Пустой участок", gid: nil, hp: 100)
        } label: {
            ZStack {
                Circle()
                    .fill(level != nil ? Color(red: 1, green: 0.84, blue: 0.47) : Color.black.opacity(0.35))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(isDamaged ? Color.red : Color.white.opacity(0.8), lineWidth: isDamaged ? 2 : 1))
                if let level {
                    Text("\(level)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                }
            }
            .shadow(color: .black.opacity(0.5), radius: 2)
        }
        .buttonStyle(.plain)
    }

    private func loadVillages() async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            let list = try await APIClient.shared.fetchVillages(token: token)
            villages = list
            let target = list.first(where: { $0.isCapital }) ?? list.first
            selectedVillageID = target?.id
            if let id = target?.id {
                await loadDetail(id: id)
            } else {
                isLoading = false
            }
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Неизвестная ошибка."
            isLoading = false
        }
    }

    private func loadDetail(id: Int) async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            detail = try await APIClient.shared.fetchVillage(id: id, token: token)
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Неизвестная ошибка."
        }
        isLoading = false
    }
}

private struct BuildingInfoSheet: View {
    let building: VillageDetail.BuildingSlot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(building.label ?? "Пустой участок").font(.title3.bold())
            if building.buildingKey != nil {
                Text("Уровень \(building.level)").foregroundStyle(.secondary)
                if building.hp < 100 {
                    Label("Повреждено (\(building.hp)%)", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } else {
                Text("Участок №\(building.slot) свободен").foregroundStyle(.secondary)
            }
            Text("Строительство и улучшения появятся здесь позже.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
    }
}
