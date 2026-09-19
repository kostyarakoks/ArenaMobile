import SwiftUI

/// The "Площадь сбора" screen (opened from the "Ещё" sheet) — Api\RallyPointController, same
/// MovementService the web Village/RallyPoint.vue page uses: stationed troops, incoming/
/// outgoing movements, and sending an attack/raid/reinforce/settle. Training new troops
/// (Api\TroopController, one of the 4 training buildings) opens as a sheet from here.
struct RallyPointView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var villages: [VillageSummary] = []
    @State private var selectedVillageID: Int?
    @State private var detail: RallyPointDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showSend = false
    @State private var showTrain = false

    var body: some View {
        content
            .navigationTitle("Площадь сбора")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Обучение") { showTrain = true }
                }
            }
            .task {
                guard villages.isEmpty else { return }
                await loadVillages()
            }
            .refreshable { await load() }
            .sheet(isPresented: $showSend) {
                if let detail {
                    SendTroopsSheet(detail: detail) { type, x, y, units in
                        await send(type: type, x: x, y: y, units: units)
                    }
                }
            }
            .sheet(isPresented: $showTrain) {
                if let id = selectedVillageID {
                    TrainingSheet(villageID: id)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && detail == nil {
            ProgressView("Загрузка…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить площадь сбора").font(.headline)
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Повторить") { Task { await load() } }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let detail {
            List {
                Section {
                    Button { showSend = true } label: { Label("Отправить войска", systemImage: "arrow.up.right.circle") }
                }
                Section("Войска в деревне") {
                    if detail.troops.isEmpty {
                        Text("Нет войск.").foregroundStyle(.secondary)
                    }
                    ForEach(detail.troops) { t in
                        HStack { Text(t.label); Spacer(); Text("\(t.count)").monospacedDigit() }
                    }
                }
                if !detail.outgoing.isEmpty {
                    Section("Исходящие") {
                        ForEach(detail.outgoing) { m in movementRow(m) }
                    }
                }
                if !detail.incoming.isEmpty {
                    Section("Входящие") {
                        ForEach(detail.incoming) { m in movementRow(m) }
                    }
                }
            }
            .listStyle(.insetGrouped)
        } else {
            Color.clear
        }
    }

    private func movementRow(_ m: RallyPointDetail.Movement) -> some View {
        HStack {
            Text(movementLabel(m.type, isReturn: m.isReturn)).font(.footnote)
            Spacer()
            Text("(\(m.targetX)|\(m.targetY))").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func movementLabel(_ type: String, isReturn: Bool) -> String {
        if isReturn { return "Возвращение" }
        switch type {
        case "attack": return "⚔️ Атака"
        case "raid": return "🏹 Набег"
        case "reinforce": return "🛡️ Подкрепление"
        case "settle": return "🏰 Основание"
        default: return type
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
            detail = try await APIClient.shared.fetchRallyPoint(villageID: id, token: token)
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
        isLoading = false
    }

    private func send(type: String, x: Int, y: Int, units: [String: Int]) async {
        guard let token = session.bearerToken, let id = selectedVillageID else { return }
        do {
            try await APIClient.shared.sendTroops(villageID: id, type: type, targetX: x, targetY: y, units: units, token: token)
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }
}

private struct SendTroopsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let detail: RallyPointDetail
    let onSubmit: (String, Int, Int, [String: Int]) async -> Void

    @State private var type = "attack"
    @State private var targetX = 0
    @State private var targetY = 0
    @State private var unitCounts: [String: Int] = [:]

    private let types: [(key: String, label: String)] = [
        ("attack", "⚔️ Атака"), ("raid", "🏹 Набег"), ("reinforce", "🛡️ Подкрепление"), ("settle", "🏰 Основание"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Тип похода") {
                    Picker("Тип", selection: $type) {
                        ForEach(types, id: \.key) { t in Text(t.label).tag(t.key) }
                    }
                }
                Section("Координаты цели") {
                    Stepper("X: \(targetX)", value: $targetX, in: -detail.worldHalf...detail.worldHalf)
                    Stepper("Y: \(targetY)", value: $targetY, in: -detail.worldHalf...detail.worldHalf)
                    if !detail.myOtherVillages.isEmpty {
                        Menu("Свои деревни") {
                            ForEach(detail.myOtherVillages) { v in
                                Button("\(v.name) (\(v.x)|\(v.y))") { targetX = v.x; targetY = v.y }
                            }
                        }
                    }
                    if !detail.allianceVillages.isEmpty {
                        Menu("Деревни союзников") {
                            ForEach(detail.allianceVillages) { v in
                                Button("\(v.name) — \(v.owner) (\(v.x)|\(v.y))") { targetX = v.x; targetY = v.y }
                            }
                        }
                    }
                }
                Section("Войска") {
                    if detail.troops.isEmpty {
                        Text("Нет войск для отправки.").foregroundStyle(.secondary)
                    }
                    ForEach(detail.troops) { t in
                        Stepper("\(t.label): \(unitCounts[t.unitKey] ?? 0)", value: Binding(
                            get: { unitCounts[t.unitKey] ?? 0 },
                            set: { unitCounts[t.unitKey] = $0 }
                        ), in: 0...t.count)
                    }
                }
            }
            .navigationTitle("Отправить войска")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Отправить") {
                        Task {
                            await onSubmit(type, targetX, targetY, unitCounts.filter { $0.value > 0 })
                            dismiss()
                        }
                    }
                    .disabled(unitCounts.values.allSatisfy { $0 == 0 })
                }
            }
        }
    }
}

private struct TrainingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: AuthSession
    let villageID: Int

    @State private var building = "barracks"
    @State private var detail: TrainingDetail?
    @State private var isLoading = true
    @State private var isBusy = false

    private let buildings: [(key: String, label: String)] = [
        ("barracks", "Казарма"), ("stable", "Конюшня"), ("workshop", "Мастерская"), ("residence", "Резиденция"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Здание", selection: $building) {
                    ForEach(buildings, id: \.key) { b in Text(b.label).tag(b.key) }
                }
                .pickerStyle(.segmented)
                .padding(12)
                .onChange(of: building) { _ in Task { await load() } }

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let detail {
                    List {
                        if !detail.queue.isEmpty {
                            Section("Очередь") {
                                ForEach(detail.queue) { q in
                                    HStack {
                                        Text(q.label)
                                        Spacer()
                                        Text("\(q.trained)/\(q.count)").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        Section("Юниты") {
                            ForEach(detail.units) { unit in
                                TrainUnitRow(unit: unit, isBusy: isBusy) { count in
                                    Task { await train(unitKey: unit.key, count: count) }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    Color.clear
                }
            }
            .navigationTitle("Обучение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }
            }
            .task { await load() }
        }
    }

    private func load() async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        detail = try? await APIClient.shared.fetchTraining(villageID: villageID, building: building, token: token)
        isLoading = false
    }

    private func train(unitKey: String, count: Int) async {
        guard let token = session.bearerToken, count > 0 else { return }
        isBusy = true
        defer { isBusy = false }
        try? await APIClient.shared.train(villageID: villageID, building: building, unitKey: unitKey, count: count, token: token)
        await load()
    }
}

private struct TrainUnitRow: View {
    let unit: TrainingDetail.TrainableUnit
    let isBusy: Bool
    let onTrain: (Int) -> Void

    @State private var count = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(unit.label).font(.footnote.bold())
            Text("⚔️\(unit.attack) 🛡️\(unit.defInf)/\(unit.defCav) · макс. \(unit.maxAffordable)")
                .font(.caption2).foregroundStyle(.secondary)
            if unit.locked {
                Text("Недоступно").font(.caption2).foregroundStyle(.orange)
            } else {
                HStack {
                    Stepper("Кол-во: \(count)", value: $count, in: 1...max(1, unit.maxAffordable))
                    Button("Обучить") { onTrain(count) }
                        .font(.caption)
                        .disabled(isBusy || unit.maxAffordable < 1)
                }
            }
        }
    }
}
