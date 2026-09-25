import SwiftUI

/// Нижний док с 6 кнопками (5 динамических + «Ещё»).
/// Используется и в MainTabView (обычные экраны), и в VillageMapView
/// (карта деревни), чтобы карта могла уходить под док, а он сам рисовался
/// поверх неё.
struct BottomDockView: View {
    @EnvironmentObject private var navState: NavigationState

    private let dockHeight: CGFloat = 74
    private let crestOverlap: CGFloat = 21

    private var isOnMap: Bool { navState.selected.id == "map" }
    private var isOnMapOrVillage: Bool {
        navState.selected.id == "village" || navState.selected.id == "map"
    }
    private var toggleItem: NavItem {
        isOnMapOrVillage ? (isOnMap ? .village : .map) : navState.lastMapOrVillage
    }
    private var dockItems: [NavItem] {
        [toggleItem] + NavItem.mainItems.filter { $0.id != "village" && $0.id != "map" }
    }
    private func isDockItemActive(_ item: NavItem) -> Bool {
        (item.id == "village" || item.id == "map")
            ? (navState.selected.id == "village" || navState.selected.id == "map")
            : item == navState.selected
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(dockItems) { item in
                dockButton(item: item, isActive: isDockItemActive(item)) {
                    navState.selected = item
                }
            }
            dockButton(label: "Ещё", icon: "⋯", img: "nav_more", isActive: navState.showMore) {
                navState.showMore = true
            }
        }
        .frame(height: dockHeight)
        .padding(.top, crestOverlap)
        .background(
            Image("nav_bar_bg")
                .resizable(resizingMode: .stretch)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Image("nav_crest")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 22)
                     .offset(y: -10)
                .allowsHitTesting(false)
        }
    }

    private func dockButton(item: NavItem, isActive: Bool, action: @escaping () -> Void) -> some View {
        dockButton(label: item.label, icon: item.icon, img: item.img, isActive: isActive, action: action)
    }

    private func dockButton(label: String, icon: String, img: String?, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                if let img {
                    Image(img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 31, height: 31)
                        .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                } else {
                    Text(icon).font(.system(size: 24))
                }
                Text(label).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(isActive ? Color(red: 1, green: 0.84, blue: 0.47) : .white.opacity(0.75))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.vertical, 6)
            .background(isActive ? Color.white.opacity(0.08) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}