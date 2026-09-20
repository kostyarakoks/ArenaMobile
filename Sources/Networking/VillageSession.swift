import Foundation

/// Shared "active village" state — the player's village list plus the currently-selected
/// village's full detail (resources, buildings, queue). Used to live as VillageMapView's own
/// local @State; lifted out into its own EnvironmentObject (created once by MainTabView, same
/// lifetime as AuthSession's signed-in session) so the GLOBAL resources header (GameHeaderBar)
/// and the village map screen both read the same data instead of fetching it twice, and so
/// MapOverlayControls' village switcher can change it from either map screen.
@MainActor
final class VillageSession: ObservableObject {
    @Published private(set) var villages: [VillageSummary] = []
    @Published private(set) var selectedVillageID: Int?
    @Published private(set) var detail: VillageDetail?
    @Published private(set) var isLoading = true
    @Published var errorMessage: String?

    private var didLoad = false

    var selectedVillage: VillageSummary? {
        villages.first { $0.id == selectedVillageID }
    }

    /// Called from MainTabView's `.task` — safe to call on every appearance, only actually
    /// fetches once per signed-in session.
    func loadIfNeeded(_ session: AuthSession) async {
        guard !didLoad else { return }
        didLoad = true
        await loadVillages(session)
    }

    func loadVillages(_ session: AuthSession) async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            let list = try await APIClient.shared.fetchVillages(token: token)
            villages = list
            let target = list.first(where: { $0.id == selectedVillageID }) ?? list.first(where: { $0.isCapital }) ?? list.first
            if let id = target?.id {
                await loadDetail(id: id, session)
            } else {
                selectedVillageID = nil
                detail = nil
                isLoading = false
            }
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Неизвестная ошибка."
            isLoading = false
        }
    }

    func loadDetail(id: Int, _ session: AuthSession) async {
        guard let token = session.bearerToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            detail = try await APIClient.shared.fetchVillage(id: id, token: token)
            selectedVillageID = id
        } catch {
            session.signOutIfUnauthorized(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Неизвестная ошибка."
        }
        isLoading = false
    }

    /// Village switcher action (MapOverlayControls) — no-ops if already selected, otherwise
    /// fetches the new village's detail in the background.
    func selectVillage(id: Int, _ session: AuthSession) {
        guard id != selectedVillageID else { return }
        Task { await loadDetail(id: id, session) }
    }

    /// GameHeaderBar's refresh button, and SlotActionSheet's onChanged after a build/upgrade
    /// action — re-fetches whichever village is currently selected.
    func refreshSelected(_ session: AuthSession) {
        guard let id = selectedVillageID else { return }
        Task { await loadDetail(id: id, session) }
    }
}
