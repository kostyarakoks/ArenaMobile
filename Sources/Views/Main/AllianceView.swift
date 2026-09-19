import SwiftUI

/// The "Альянс" tab — Api\AllianceController (travianz-laravel), same AllianceService the web
/// Alliance/Index.vue + Alliance/Show.vue pages use, combined into one screen: my alliance (if
/// any) with its member list and a leave button, or the browsable list + create/join otherwise.
struct AllianceView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var alliances: [AllianceSummary] = []
    @State private var myAlliance: AllianceDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var showCreate = false

    var body: some View {
        content
            .navigationTitle("Альянс")
            .toolbar {
                if myAlliance == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showCreate = true } label: { Image(systemName: "plus") }
                    }
                }
            }
            .task {
                guard alliances.isEmpty, myAlliance == nil else { return }
                await load()
            }
            .refreshable { await load() }
            .sheet(isPresented: $showCreate) {
                CreateAllianceSheet { name, tag, description in
                    await create(name: name, tag: tag, description: description)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && alliances.isEmpty && myAlliance == nil {
            ProgressView("Загрузка альянсов…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить альянсы").font(.headline)
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Повторить") { Task { await load() } }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let myAlliance {
            myAllianceList(myAlliance)
        } else {
            browseList
        }
    }

    private func myAllianceList(_ alliance: AllianceDetail) -> some View {
        List {
            Section {
                Text("[\(alliance.tag)] \(alliance.name)").font(.title3.bold())
                if let description = alliance.description, !description.isEmpty {
                    Text(description).font(.footnote).foregroundStyle(.secondary)
                }
                if let leader = alliance.leader {
                    Text("Лидер: \(leader)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Участники (\(alliance.members.count))") {
                ForEach(alliance.members) { member in
                    HStack {
                        Text(member.name)
                        if let role = member.role, !role.isEmpty {
                            Text(role).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(member.villagesCount) 🏘️").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Button(role: .destructive) { Task { await leave() } } label: {
                    Text("Покинуть альянс")
                }
                .disabled(isBusy)
            }
        }
        .listStyle(.insetGrouped)
        .disabled(isBusy)
    }

    private var browseList: some View {
        List {
            if alliances.isEmpty {
                Text("Альянсов пока нет — создайте первый.").foregroundStyle(.secondary)
            }
            ForEach(alliances) { alliance in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("[\(alliance.tag)] \(alliance.name)").font(.subheadline.bold())
                        Text("\(alliance.membersCount) участников").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Вступить") { Task { await join(id: alliance.id) } }
                        .font(.caption)
                        .disabled(isBusy)
                }
            }
        }
        .listStyle(.insetGrouped)
        .disabled(isBusy)
    }

    private func load() async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            if let allianceId = session.currentUser?.allianceId {
                myAlliance = try await APIClient.shared.fetchAlliance(id: allianceId, token: token)
            } else {
                myAlliance = nil
                alliances = try await APIClient.shared.fetchAlliances(token: token)
            }
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
        isLoading = false
    }

    private func create(name: String, tag: String, description: String?) async {
        guard let token = session.bearerToken else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.createAlliance(name: name, tag: tag, description: description, token: token)
            await session.refreshCurrentUser()
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    private func join(id: Int) async {
        guard let token = session.bearerToken else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.joinAlliance(id: id, token: token)
            await session.refreshCurrentUser()
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    private func leave() async {
        guard let token = session.bearerToken else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.leaveAlliance(token: token)
            await session.refreshCurrentUser()
            myAlliance = nil
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }
}

private struct CreateAllianceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSubmit: (String, String, String?) async -> Void

    @State private var name = ""
    @State private var tag = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Название", text: $name)
                TextField("Тег (до 8 символов)", text: $tag)
                    .onChange(of: tag) { newValue in
                        // Single-parameter onChange — this project's deployment target is iOS 16
                        // (see LoginView.swift's serverURL field for the same note).
                        if newValue.count > 8 { tag = String(newValue.prefix(8)) }
                    }
                TextField("Описание (необязательно)", text: $description, axis: .vertical)
                    .lineLimit(3...6)
            }
            .navigationTitle("Новый альянс")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        Task {
                            await onSubmit(name, tag, description.isEmpty ? nil : description)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || tag.isEmpty)
                }
            }
        }
    }
}
