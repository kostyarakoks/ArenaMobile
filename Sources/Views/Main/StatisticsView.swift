import SwiftUI

/// The "Статистика" screen — Api\StatisticsController (travianz-laravel): 4 server-wide
/// leaderboards (population/production/offense/defense), same ResourceService-derived numbers
/// the web Statistics/Index.vue page shows, cached 5 minutes server-side.
struct StatisticsView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var response: StatisticsResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var metric = LeaderboardMetric.population

    var body: some View {
        content
            .gameListBackground()
            .withScreenTitle { ScreenTitleBar("Статистика") }
            .task {
                guard response == nil else { return }
                await load()
            }
            .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            Picker("", selection: $metric) {
                ForEach(LeaderboardMetric.allCases) { m in Text(m.label).tag(m) }
            }
            .pickerStyle(.segmented)
            .padding(12)

            if isLoading && response == nil {
                ProgressView("Загрузка статистики…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text("Не удалось загрузить статистику").font(.headline)
                    Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
                    Button("Повторить") { Task { await load() } }
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let response {
                let rows = metric.rows(in: response.leaderboard)
                List {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        HStack {
                            Text("#\(index + 1)")
                                .font(.caption)
                                .foregroundStyle(index == 0 ? GameTheme.amber : GameTheme.textMuted)
                                .frame(width: 32, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.name).font(.footnote).foregroundStyle(index == 0 ? GameTheme.amber : GameTheme.textPrimary)
                                Text("\(row.villagesCount) 🏘️").font(.caption2).foregroundStyle(GameTheme.textSecondary)
                            }
                            Spacer()
                            Text("\(metric.value(row))").font(.footnote.bold().monospacedDigit()).foregroundStyle(GameTheme.textPrimary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                Color.clear
            }
        }
    }

    private func load() async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            response = try await APIClient.shared.fetchStatistics(token: token)
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
        isLoading = false
    }
}
