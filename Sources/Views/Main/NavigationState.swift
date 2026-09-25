import Foundation

/// Глобальное состояние навигации верхнего уровня (какая вкладка открыта,
/// показан ли sheet «Ещё», какая из пары village/map была последней активной).
/// Живёт в MainTabView и прокидывается через `.environmentObject` во все
/// экраны, которым нужно переключать вкладку (BottomDockView, GameHeaderBar,
/// VillageMapView).
@MainActor
final class NavigationState: ObservableObject {
    @Published var selected: NavItem = .village
    @Published var showMore: Bool = false
    @Published var lastMapOrVillage: NavItem = .village
}