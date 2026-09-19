import SwiftUI

/// The "Отчёты" screen — Api\ReportController (travianz-laravel), same BattleReport model the
/// web Reports/Index.vue + Reports/Show.vue pages use.
struct ReportsView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var reports: [ReportSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selected: ReportSummary?

    var body: some View {
        content
            .navigationTitle("Отчёты")
            .task {
                guard reports.isEmpty else { return }
                await load()
            }
            .refreshable { await load() }
            .sheet(item: $selected) { report in
                ReportDetailSheet(reportID: report.id)
            }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && reports.isEmpty {
            ProgressView("Загрузка отчётов…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить отчёты").font(.headline)
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Повторить") { Task { await load() } }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if reports.isEmpty {
            Text("Отчётов пока нет.").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(reports) { report in
                    Button { selected = report } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(typeLabel(report)).font(.footnote.bold())
                                    .foregroundStyle(report.iAmAttacker == report.attackerWon ? .green : .red)
                                Text("\(report.attacker ?? "?") → \(report.defender ?? "?")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !report.isRead {
                                Circle().fill(Color.blue).frame(width: 8, height: 8)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) { Task { await delete(report) } } label: { Label("Удалить", systemImage: "trash") }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func typeLabel(_ report: ReportSummary) -> String {
        let won = report.iAmAttacker == report.attackerWon
        let icon = report.captured ? "🏰" : (won ? "✅" : "❌")
        return "\(icon) \(report.type)"
    }

    private func load() async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            reports = try await APIClient.shared.fetchReports(token: token)
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
        isLoading = false
    }

    private func delete(_ report: ReportSummary) async {
        guard let token = session.bearerToken else { return }
        try? await APIClient.shared.deleteReport(id: report.id, token: token)
        await load()
    }
}

private struct ReportDetailSheet: View {
    @EnvironmentObject private var session: AuthSession
    let reportID: Int

    @State private var detail: ReportDetail?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let detail {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(detail.attackerWon ? "Победа атакующего" : "Победа обороняющегося")
                                .font(.headline)
                            Text("\(detail.attacker ?? "?") (\(detail.attackerVillage ?? "?")) → \(detail.defender ?? "?") (\(detail.defenderVillage ?? "?"))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Divider()
                            Text(detail.resultJSON)
                                .font(.system(.footnote, design: .monospaced))
                        }
                        .padding()
                    }
                } else {
                    Text("Не удалось загрузить отчёт.").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Отчёт")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                guard let token = session.bearerToken else { return }
                detail = try? await APIClient.shared.fetchReport(id: reportID, token: token)
                isLoading = false
            }
        }
    }
}
