import SwiftUI

/// Native port of resources/js/Components/BottomNav.vue: a custom 6-icon dock plus a 7th "Ещё"
/// button that opens a grid sheet with everything else — not a system TabView, on purpose, so
/// the shape matches the web app exactly instead of iOS's own >5-items-collapse-to-"More"
/// behavior (which would put different items behind "More" than the web version does).
struct MainTabView: View {
    @State private var selected: NavItem = NavItem.mainItems[0]
    @State private var showMore = false

    var body: some View {
        NavigationStack {
            NavDestinationView(item: selected)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomDock
        }
        .sheet(isPresented: $showMore) {
            moreSheet
                .presentationDetents([.medium, .large])
        }
    }

    private var bottomDock: some View {
        HStack(spacing: 0) {
            ForEach(NavItem.mainItems) { item in
                dockButton(item: item, isActive: item == selected) {
                    selected = item
                }
            }
            dockButton(label: "Ещё", icon: "⋯", isActive: showMore) {
                showMore = true
            }
        }
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [Color(red: 19 / 255, green: 42 / 255, blue: 77 / 255), Color(red: 10 / 255, green: 23 / 255, blue: 48 / 255)],
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)
        }
    }

    private func dockButton(item: NavItem, isActive: Bool, action: @escaping () -> Void) -> some View {
        dockButton(label: item.label, icon: item.icon, isActive: isActive, action: action)
    }

    private func dockButton(label: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(icon).font(.system(size: 20))
                Text(label).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(isActive ? Color(red: 1, green: 0.84, blue: 0.47) : .white.opacity(0.75))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isActive ? Color.white.opacity(0.08) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var moreSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    ForEach(NavItem.moreItems) { item in
                        Button {
                            selected = item
                            showMore = false
                        } label: {
                            VStack(spacing: 6) {
                                Text(item.icon).font(.system(size: 26))
                                Text(item.label)
                                    .font(.system(size: 11))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(item == selected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Ещё")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { showMore = false }
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthSession())
}
