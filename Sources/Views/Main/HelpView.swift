import SwiftUI

/// The "Помощь" screen — Api\HelpController (travianz-laravel), the exact same lang('game.help')
/// text the web Help/Index.vue page renders.
struct HelpView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var helpContent: HelpContent?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        content
            .navigationTitle("Помощь")
            .task {
                guard helpContent == nil else { return }
                await load()
            }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && helpContent == nil {
            ProgressView("Загрузка…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить помощь").font(.headline)
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
                Button("Повторить") { Task { await load() } }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let helpContent {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(helpContent.subtitle).font(.footnote).foregroundStyle(GameTheme.textSecondary)
                    ForEach(helpContent.sections.keys.sorted(), id: \.self) { key in
                        if let section = helpContent.sections[key] {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(section.icon) \(section.title)").font(.headline).foregroundStyle(GameTheme.amber)
                                ForEach(Array(section.body.enumerated()), id: \.offset) { _, paragraph in
                                    Text(paragraph).font(.footnote).foregroundStyle(GameTheme.textPrimary)
                                }
                            }
                            .gamePanel(padding: 14)
                        }
                    }
                }
                .padding(16)
            }
            .gameScreenBackground()
        } else {
            Color.clear
        }
    }

    private func load() async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            helpContent = try await APIClient.shared.fetchHelp(token: token)
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
        isLoading = false
    }
}
