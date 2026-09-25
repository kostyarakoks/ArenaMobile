import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var session: AuthSession
    @StateObject private var villageSession = VillageSession()
    @StateObject private var navState = NavigationState()

    var body: some View {
        Group {
            if navState.selected.id == "village" {
                VillageMapView()
            } else {
                standardLayout
            }
        }
        .environmentObject(villageSession)
        .environmentObject(navState)
        .sheet(isPresented: $navState.showMore) {
            moreSheet
                .presentationDetents([.medium, .large])
        }
        .task {
            await villageSession.loadIfNeeded(session)
        }
        .onChange(of: navState.selected) { newValue in
            if newValue.id == "village" || newValue.id == "map" {
                navState.lastMapOrVillage = newValue
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var standardLayout: some View {
        VStack(spacing: 0) {
            GameHeaderBar(selectItem: { navState.selected = $0 })

            NavigationStack {
                NavDestinationView(item: navState.selected, selectItem: { navState.selected = $0 })
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            BottomDockView()
        }
    }

    private var moreSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    ForEach(NavItem.moreItems) { item in
                        Button {
                            navState.selected = item
                            navState.showMore = false
                        } label: {
                            VStack(spacing: 6) {
                                Text(item.icon).font(.system(size: 26))
                                Text(item.label)
                                    .font(.system(size: 11))
                                    .foregroundStyle(GameTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(item == navState.selected ? GameTheme.amber.opacity(0.18) : GameTheme.panelTop.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .gameScreenBackground()
            .navigationTitle("Ещё")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { navState.showMore = false }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text(AppVersion.displayString)
                    .font(.caption2)
                    .foregroundStyle(GameTheme.textMuted)
                    .padding(.bottom, 8)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthSession())
}