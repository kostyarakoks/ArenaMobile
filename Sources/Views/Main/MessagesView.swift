import SwiftUI

/// The "Сообщения" screen — Api\MessageController (travianz-laravel): inbox/sent tabs, send a
/// new message, read one, delete. The "events" box (game activity log) is available in the API
/// but not surfaced in this UI yet — messages/reports cover the main use case.
struct MessagesView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var box = "inbox"
    @State private var messages: [MessageSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedID: Int?
    @State private var showCompose = false

    var body: some View {
        content
            .navigationTitle("Сообщения")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCompose = true } label: { Image(systemName: "square.and.pencil") }
                }
            }
            .task {
                guard messages.isEmpty else { return }
                await load()
            }
            .refreshable { await load() }
            .sheet(item: Binding(get: { selectedID.map { IdentifiableInt(id: $0) } }, set: { selectedID = $0?.id })) { wrapped in
                MessageDetailSheet(messageID: wrapped.id)
            }
            .sheet(isPresented: $showCompose) {
                ComposeMessageSheet { recipient, subject, body in
                    await send(recipient: recipient, subject: subject, body: body)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            Picker("", selection: $box) {
                Text("Входящие").tag("inbox")
                Text("Отправленные").tag("sent")
            }
            .pickerStyle(.segmented)
            .padding(12)
            .onChange(of: box) { _ in Task { await load() } }

            if isLoading && messages.isEmpty {
                ProgressView("Загрузка…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text("Не удалось загрузить сообщения").font(.headline)
                    Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
                    Button("Повторить") { Task { await load() } }
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if messages.isEmpty {
                Text("Пусто.").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(messages) { message in
                        Button { selectedID = message.id } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(message.subject).font(.footnote.bold())
                                    Text(box == "inbox" ? message.sender : message.recipient)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if box == "inbox" && message.readAt == nil {
                                    Circle().fill(GameTheme.amber).frame(width: 8, height: 8)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) { Task { await delete(message) } } label: { Label("Удалить", systemImage: "trash") }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func load() async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            messages = try await APIClient.shared.fetchMessages(box: box, token: token)
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
        isLoading = false
    }

    private func delete(_ message: MessageSummary) async {
        guard let token = session.bearerToken else { return }
        try? await APIClient.shared.deleteMessage(id: message.id, token: token)
        await load()
    }

    private func send(recipient: String, subject: String, body: String) async {
        guard let token = session.bearerToken else { return }
        try? await APIClient.shared.sendMessage(recipient: recipient, subject: subject, body: body, token: token)
        if box == "sent" { await load() }
    }
}

private struct IdentifiableInt: Identifiable { let id: Int }

private struct MessageDetailSheet: View {
    @EnvironmentObject private var session: AuthSession
    let messageID: Int

    @State private var detail: MessageDetail?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let detail {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(detail.subject).font(.title3.bold()).foregroundStyle(GameTheme.amber)
                            Text(detail.isMine ? "Кому: \(detail.recipient)" : "От: \(detail.sender)")
                                .font(.footnote)
                                .foregroundStyle(GameTheme.textSecondary)
                            Divider()
                            Text(detail.body).foregroundStyle(GameTheme.textPrimary)
                        }
                        .padding()
                    }
                    .gameScreenBackground()
                } else {
                    Text("Не удалось загрузить сообщение.").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Сообщение")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                guard let token = session.bearerToken else { return }
                detail = try? await APIClient.shared.fetchMessage(id: messageID, token: token)
                isLoading = false
            }
        }
    }
}

private struct ComposeMessageSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSubmit: (String, String, String) async -> Void

    @State private var recipient = ""
    @State private var subject = ""
    @State private var messageBody = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Получатель (имя игрока)", text: $recipient)
                TextField("Тема", text: $subject)
                TextField("Текст сообщения", text: $messageBody, axis: .vertical).lineLimit(5...10)
            }
            .navigationTitle("Новое сообщение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Отправить") {
                        Task {
                            await onSubmit(recipient, subject, messageBody)
                            dismiss()
                        }
                    }
                    .disabled(recipient.isEmpty || subject.isEmpty || messageBody.isEmpty)
                }
            }
        }
    }
}
