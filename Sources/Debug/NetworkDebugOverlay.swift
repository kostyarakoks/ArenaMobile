#if DEBUG
import SwiftUI

/// The floating "test window": a small draggable bubble on every screen (see
/// DebugOverlayWindow, which hosts this in its own UIWindow above the app, sheets included)
/// that expands into a scrollable list of recent requests and collapses back with one tap.
struct NetworkDebugOverlay: View {
    @ObservedObject private var logger = NetworkDebugLogger.shared
    @State private var isExpanded = false
    @State private var bubblePosition = CGPoint(
        x: UIScreen.main.bounds.width - 36,
        y: UIScreen.main.bounds.height - 160
    )
    @State private var dragTranslation: CGSize = .zero
    @State private var selectedEntry: NetworkLogEntry?

    var body: some View {
        ZStack {
            if isExpanded {
                panel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                bubble
                    .position(x: bubblePosition.x + dragTranslation.width, y: bubblePosition.y + dragTranslation.height)
                    .gesture(
                        DragGesture()
                            .onChanged { dragTranslation = $0.translation }
                            .onEnded {
                                bubblePosition.x += $0.translation.width
                                bubblePosition.y += $0.translation.height
                                dragTranslation = .zero
                            }
                    )
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: isExpanded)
        .sheet(item: $selectedEntry) { entry in
            NetworkDebugDetailView(entry: entry)
        }
    }

    private var bubble: some View {
        Button {
            isExpanded = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color.black.opacity(0.78))
                    .frame(width: 46, height: 46)
                    .overlay(Image(systemName: "network").foregroundStyle(.white))
                    .shadow(radius: 4)

                if !logger.entries.isEmpty {
                    Text("\(logger.entries.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(Color.red))
                        .offset(x: 8, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var panel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Запросы к серверу")
                    .font(.headline)
                Spacer()
                Button {
                    logger.clear()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(logger.entries.isEmpty)

                Button {
                    isExpanded = false
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .imageScale(.large)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)

            if logger.entries.isEmpty {
                Spacer()
                Text("Пока нет запросов")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(logger.entries) { entry in
                    Button {
                        selectedEntry = entry
                    } label: {
                        row(for: entry)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.15)))
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 24)
    }

    private func row(for entry: NetworkLogEntry) -> some View {
        HStack(spacing: 10) {
            statusBadge(entry)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.method) \(pathOnly(entry.url))")
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(entry.date, style: .time)
                    if let duration = entry.duration {
                        Text(String(format: "%.0f мс", duration * 1000))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func statusBadge(_ entry: NetworkLogEntry) -> some View {
        Group {
            if entry.isPending {
                ProgressView().scaleEffect(0.7)
            } else if let code = entry.statusCode {
                Text("\(code)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(entry.isSuccess ? Color.green : Color.red)
                    .clipShape(Capsule())
            } else {
                Text("ERR")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
        }
        .frame(width: 38)
    }

    private func pathOnly(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        return url.path + (url.query.map { "?\($0)" } ?? "")
    }
}

/// Full detail for one request: exact URL, headers, and both bodies pretty-printed — enough
/// to see exactly what went out and what came back without a Mac/Proxyman nearby.
private struct NetworkDebugDetailView: View {
    let entry: NetworkLogEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("URL", entry.url)
                    section("Метод", entry.method)
                    if let code = entry.statusCode {
                        section("Статус", "\(code)")
                    }
                    if let duration = entry.duration {
                        section("Время", String(format: "%.0f мс", duration * 1000))
                    }
                    if let error = entry.errorDescription {
                        section("Ошибка", error)
                    }
                    if !entry.requestHeaders.isEmpty {
                        section("Заголовки запроса", headersText(entry.requestHeaders))
                    }
                    if let body = entry.requestBody {
                        section("Тело запроса", body)
                    }
                    if let headers = entry.responseHeaders, !headers.isEmpty {
                        section("Заголовки ответа", headersText(headers))
                    }
                    if let body = entry.responseBody {
                        section("Тело ответа", body)
                    }
                }
                .padding()
            }
            .navigationTitle("Запрос")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    private func section(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headersText(_ headers: [String: String]) -> String {
        headers.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
    }
}
#endif
