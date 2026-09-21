import SwiftUI

/// The "Рюкзак" screen — Api\BackpackController (travianz-laravel), same InventoryService the
/// web Backpack/Index.vue page uses: owned items grouped by category, with a "use" action for
/// the ones that aren't purely cosmetic/equipment (equipment is used from HeroView instead).
struct BackpackView: View {
    @EnvironmentObject private var session: AuthSession

    @State private var response: BackpackResponse?
    @State private var villages: [VillageSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isBusy = false

    // "в рюкзаке сделать сделать все иконками, при клики на вещь, открывается как в скрине" —
    // was a plain List of text rows; the reference screenshot the user sent (a category tab row
    // + a grid of icon tiles, tapping one opens a detail card with description + action inline
    // below the grid) is a different SHAPE entirely, not just a style tweak. Rebuilt around that
    // shape using this screen's real data/actions (a fixed quantity + a single "Использовать"
    // action, not the reference's quantity slider — that slider belongs to a different game's
    // "spend N of a stackable currency" flow that InventoryService/BackpackController don't
    // support here, and faking one that doesn't actually do anything would be worse than not
    // having it).
    @State private var selectedCategory: BackpackCategory = .resources
    @State private var selectedItemKey: String?

    var body: some View {
        content
            .gameScreenBackground()
            .withScreenTitle { ScreenTitleBar("Рюкзак") }
            .task {
                guard response == nil else { return }
                await load()
            }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && response == nil {
            ProgressView("Загрузка рюкзака…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text("Не удалось загрузить рюкзак").font(.headline).foregroundStyle(GameTheme.textPrimary)
                Text(errorMessage).font(.footnote).foregroundStyle(GameTheme.textSecondary).multilineTextAlignment(.center)
                Button("Повторить") { Task { await load() } }
                    .buttonStyle(.gamePrimary)
                    .fixedSize()
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let response {
            ScrollView {
                VStack(spacing: 16) {
                    categoryTabs

                    let items = response.items[selectedCategory.rawValue] ?? []
                    if items.isEmpty {
                        Text("В этой категории пока пусто.")
                            .font(.footnote)
                            .foregroundStyle(GameTheme.textMuted)
                            .padding(.top, 32)
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(items) { item in
                                itemTile(item, isSelected: item.itemKey == selectedItemKey)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedItemKey = (selectedItemKey == item.itemKey) ? nil : item.itemKey
                                        }
                                    }
                            }
                        }

                        if let selectedItemKey, let item = items.first(where: { $0.itemKey == selectedItemKey }) {
                            itemDetailCard(item)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(16)
                .animation(.easeInOut(duration: 0.15), value: selectedItemKey)
            }
            .refreshable { await load() }
            .disabled(isBusy)
            // Switching category with a detail card open for an item that's no longer visible
            // would leave a stale card on screen with nothing highlighted under it.
            .onChange(of: selectedCategory) { _ in selectedItemKey = nil }
        } else {
            Color.clear
        }
    }

    private var categoryTabs: some View {
        HStack(spacing: 6) {
            ForEach(BackpackCategory.allCases) { category in
                let count = (response?.items[category.rawValue] ?? []).count
                Button {
                    selectedCategory = category
                } label: {
                    Text(category.label)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(selectedCategory == category ? GameTheme.btnText : GameTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                if selectedCategory == category {
                                    LinearGradient(colors: [GameTheme.btnTop, GameTheme.btnBottom], startPoint: .top, endPoint: .bottom)
                                } else {
                                    LinearGradient(colors: [GameTheme.panelTop, GameTheme.panelBottom], startPoint: .top, endPoint: .bottom)
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .opacity(count == 0 ? 0.4 : 1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func itemTile(_ item: BackpackItem, isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            Text(item.icon ?? "🎁")
                .font(.system(size: 30))
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(
                    LinearGradient(colors: [GameTheme.panelTop, GameTheme.panelBottom], startPoint: .top, endPoint: .bottom)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? GameTheme.amber : GameTheme.panelBorder, lineWidth: isSelected ? 2 : 1)
                )
                .overlay(alignment: .bottomTrailing) {
                    Text(compactQuantity(item.quantity))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(GameTheme.textPrimary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(3)
                }
        }
    }

    /// Mirrors the reference screenshot's own "1 K" / "10 K" shorthand on crowded item tiles —
    /// full numbers wrap awkwardly at this tile size.
    private func compactQuantity(_ quantity: Int) -> String {
        if quantity >= 1000 { return "\(quantity / 1000) K" }
        return "\(quantity)"
    }

    private func itemDetailCard(_ item: BackpackItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(item.label) (\(item.quantity))")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(GameTheme.amber)
            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(GameTheme.textSecondary)
            }
            if item.usable {
                Button("Использовать") { Task { await use(itemKey: item.itemKey) } }
                    .buttonStyle(.gamePrimary)
                    .disabled(isBusy || villages.isEmpty)
            } else {
                Text("Этот предмет расходуется автоматически.")
                    .font(.caption)
                    .foregroundStyle(GameTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gamePanel(padding: 14)
    }

    private func load() async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            response = try await APIClient.shared.fetchBackpack(token: token)
            if villages.isEmpty {
                villages = (try? await APIClient.shared.fetchVillages(token: token)) ?? []
            }
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
        isLoading = false
    }

    private func use(itemKey: String) async {
        guard let token = session.bearerToken, let villageID = villages.first?.id else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.useBackpackItem(itemKey: itemKey, villageID: villageID, token: token)
            await load()
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }
}
