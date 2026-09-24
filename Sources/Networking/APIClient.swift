import Foundation

enum APIError: LocalizedError {
    case invalidServerURL
    case server(message: String)
    case decoding
    case unauthorized
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "Некорректный адрес сервера. Проверьте URL в настройках."
        case .server(let message):
            return message
        case .decoding:
            return "Сервер ответил в неожиданном формате."
        case .unauthorized:
            return "Сессия истекла, войдите заново."
        case .transport(let error):
            return "Нет соединения с сервером: \(error.localizedDescription)"
        }
    }
}

/// Talks to the Laravel backend's bearer-token API (routes/api.php + AuthController — see the
/// travianz-laravel repo). Only login/me/logout exist server-side so far; add more methods here
/// as routes/api.php grows past just auth.
final class APIClient {
    static let shared = APIClient()

    static let baseURLDefaultsKey = "api.baseURL"
    static let defaultServerURLString = "https://arenaoflords.ru"

    var baseURL: URL? {
        URL(string: Self.defaultServerURLString)
    }

    private let session: URLSession = .shared
    private let decoder: JSONDecoder = .init()

    private struct LoginResponse: Codable {
        let token: String
        let user: GameUser
    }

    private struct MeResponse: Codable {
        let user: GameUser
    }

    private struct ErrorResponse: Codable {
        let message: String?
    }

    func login(email: String, password: String, deviceName: String) async throws -> (token: String, user: GameUser) {
        var request = try makeRequest(path: "/api/login", method: "POST")
        request.httpBody = try JSONEncoder().encode([
            "email": email,
            "password": password,
            "device_name": deviceName,
        ])

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)

        guard let decoded = try? decoder.decode(LoginResponse.self, from: data) else {
            throw APIError.decoding
        }
        return (decoded.token, decoded.user)
    }

    /// Тело запроса на регистрацию. `name` — опциональный: клиент его больше не передаёт,
    /// сервер сам генерирует "Игрок id{ID}". `game_center_player_id` — обязательный
    /// (Api\AuthController::register() валидирует его как `required`): именно по нему
    /// сервер понимает, что устройство уже регистрировалось, и возвращает токен
    /// существующего аккаунта вместо создания нового.
    ///
    /// `Encodable` с опциональным `name` при `nil` вообще не включает это поле в JSON —
    /// так что если хочется отправить "Игрок" с клиента, можно; если нет — сервер сам
    /// подставит дефолт из lang/{locale}/game.php.
    private struct RegisterBody: Encodable {
        let name: String?
        let tribe: String
        let device_name: String
        let game_center_player_id: String
    }

    /// POST /api/register — основной путь авторизации в приложении. Игрок тапает "Играть",
    /// iOS отдаёт свой teamPlayerID (см. GameCenterAuth.swift), сервер по нему либо
    /// логинит в существующий аккаунт, либо создаёт нового пользователя.
    ///
    /// Возвращаемый `user` может быть НЕ свежезарегистрированным — если у этого
    /// teamPlayerID уже есть аккаунт на сервере, вернётся именно он (та же деревня,
    /// тот же прогресс). Это и есть защита от повторных регистраций: удаление/
    /// переустановка приложения не сбрасывает teamPlayerID, привязанный к Apple ID.
    ///
    /// `name` оставлен опциональным на случай, если в будущем появится экран
    /// "введите имя" — сейчас iOS его не передаёт (передаёт nil), а сервер сам
    /// генерирует "Игрок id{N}".
    func register(
        name: String?,
        tribe: String,
        deviceName: String,
        gameCenterPlayerID: String
    ) async throws -> (token: String, user: GameUser) {
        var request = try makeRequest(path: "/api/register", method: "POST")
        let body = RegisterBody(
            name: name,
            tribe: tribe,
            device_name: deviceName,
            game_center_player_id: gameCenterPlayerID
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)

        guard let decoded = try? decoder.decode(LoginResponse.self, from: data) else {
            throw APIError.decoding
        }
        return (decoded.token, decoded.user)
    }

    func fetchMe(token: String) async throws -> GameUser {
        var request = try makeRequest(path: "/api/me", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)

        guard let decoded = try? decoder.decode(MeResponse.self, from: data) else {
            throw APIError.decoding
        }
        return decoded.user
    }

    private struct VillagesResponse: Codable {
        let villages: [VillageSummary]
    }

    func fetchVillages(token: String) async throws -> [VillageSummary] {
        var request = try makeRequest(path: "/api/villages", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)

        guard let decoded = try? decoder.decode(VillagesResponse.self, from: data) else {
            throw APIError.decoding
        }
        return decoded.villages
    }

    func fetchVillage(id: Int, token: String) async throws -> VillageDetail {
        var request = try makeRequest(path: "/api/villages/\(id)", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)

        guard let decoded = try? decoder.decode(VillageDetail.self, from: data) else {
            throw APIError.decoding
        }
        return decoded
    }

    private struct RenameVillageBody: Encodable { let name: String }

    /// PATCH /api/villages/{village} — mirrors Api\VillageController::update(), gated
    /// server-side on Main Building level 2 (per "добавить возможность название деревни при
    /// достижение 2 уровня главного здания").
    func renameVillage(id: Int, name: String, token: String) async throws {
        var request = try makeRequest(path: "/api/villages/\(id)", method: "PATCH")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(RenameVillageBody(name: name))

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    private struct DeviceTokenBody: Encodable { let token: String }

    /// POST /api/device-tokens — mirrors Api\DeviceTokenController::store(). Called by
    /// PushNotificationManager once it has BOTH a real APNs token (from
    /// AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken) and a signed-in bearer
    /// token, in whichever order those two happen to arrive.
    func registerDeviceToken(_ deviceToken: String, token: String) async throws {
        var request = try makeRequest(path: "/api/device-tokens", method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(DeviceTokenBody(token: deviceToken))

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    /// DELETE /api/device-tokens — called from AuthSession.logout() so a signed-out device
    /// stops receiving pushes meant for the account it just left (best-effort, same as
    /// logout() below — a failure here must never block the actual sign-out).
    func unregisterDeviceToken(_ deviceToken: String, token: String) async {
        guard var request = try? makeRequest(path: "/api/device-tokens", method: "DELETE") else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(DeviceTokenBody(token: deviceToken))
        _ = try? await perform(request)
    }

    /// GET /api/villages/{village}/fields — resource-field (dorf1/"Поля") map, mirrors
    /// Api\VillageController::fields(). See FieldsResponse's own doc comment for why this is
    /// one call, unlike the building slot's separate catalogue fetch.
    func fetchFields(villageID: Int, token: String) async throws -> FieldsResponse {
        var request = try makeRequest(path: "/api/villages/\(villageID)/fields", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)

        guard let decoded = try? decoder.decode(FieldsResponse.self, from: data) else {
            throw APIError.decoding
        }
        return decoded
    }

    private struct FieldActionBody: Encodable { let instant: Bool }

    /// POST /api/villages/{village}/fields/{field}/upgrade — mirrors Api\VillageController::
    /// fieldAction(), same instant-finish-for-💎 option performSlotAction() has for buildings.
    func upgradeField(villageID: Int, fieldID: Int, instant: Bool, token: String) async throws {
        var request = try makeRequest(path: "/api/villages/\(villageID)/fields/\(fieldID)/upgrade", method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(FieldActionBody(instant: instant))

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    /// GET /api/villages/{village}/slots/{slot} — "what can I build/upgrade here" catalogue,
    /// same data VillageMapView's build-picker/upgrade sheet renders (mirrors
    /// UpgradeModal.vue/EmptyPlotOverlay.vue's fetch on the web).
    func fetchVillageSlot(villageID: Int, slot: Int, token: String) async throws -> SlotDetail {
        var request = try makeRequest(path: "/api/villages/\(villageID)/slots/\(slot)", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)

        guard let decoded = try? decoder.decode(SlotDetail.self, from: data) else {
            throw APIError.decoding
        }
        return decoded
    }

    private struct SlotActionBody: Encodable { let building_key: String; let instant: Bool }

    /// POST /api/villages/{village}/slots/{slot} — build (empty plot) or upgrade (built plot),
    /// optionally paying crystals to finish instantly (mirrors UpgradeModal.vue's "Улучшить" /
    /// "Завершить за 💎" buttons — Api\VillageController::slotAction()).
    func performSlotAction(villageID: Int, slot: Int, buildingKey: String, instant: Bool, token: String) async throws {
        var request = try makeRequest(path: "/api/villages/\(villageID)/slots/\(slot)", method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(SlotActionBody(building_key: buildingKey, instant: instant))

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    func fetchWorldMap(centerX: Int, centerY: Int, token: String) async throws -> WorldMapResponse {
        var request = try makeRequest(path: "/api/map?x=\(centerX)&y=\(centerY)", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)

        guard let decoded = try? decoder.decode(WorldMapResponse.self, from: data) else {
            throw APIError.decoding
        }
        return decoded
    }

    func fetchPublicVillage(id: Int, token: String) async throws -> PublicVillage {
        var request = try makeRequest(path: "/api/map/villages/\(id)", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)

        guard let decoded = try? decoder.decode(PublicVillage.self, from: data) else {
            throw APIError.decoding
        }
        return decoded
    }

    private struct AllocateBody: Encodable { let attribute: String; let points: Int }
    private struct EquipBody: Encodable { let slot: String; let item_key: String }
    private struct UnequipBody: Encodable { let slot: String }
    private struct CraftBody: Encodable { let item_key: String; let village_id: Int }

    func fetchHero(token: String) async throws -> HeroDetail {
        var request = try makeRequest(path: "/api/hero", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)

        guard let decoded = try? decoder.decode(HeroDetail.self, from: data) else {
            throw APIError.decoding
        }
        return decoded
    }

    /// Shared by allocate/equip/unequip/craft — all 4 just need "did it work", the caller
    /// refetches fetchHero() afterwards to pick up the new state (same round-trip the web app's
    /// own Inertia redirect-back does).
    private func postHeroAction(path: String, body: Encodable, token: String) async throws {
        var request = try makeRequest(path: path, method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    func allocateHeroPoints(attribute: String, points: Int, token: String) async throws {
        try await postHeroAction(path: "/api/hero/allocate", body: AllocateBody(attribute: attribute, points: points), token: token)
    }

    func equipHeroItem(slot: String, itemKey: String, token: String) async throws {
        try await postHeroAction(path: "/api/hero/equip", body: EquipBody(slot: slot, item_key: itemKey), token: token)
    }

    func unequipHeroItem(slot: String, token: String) async throws {
        try await postHeroAction(path: "/api/hero/unequip", body: UnequipBody(slot: slot), token: token)
    }

    func craftHeroItem(itemKey: String, villageID: Int, token: String) async throws {
        try await postHeroAction(path: "/api/hero/craft", body: CraftBody(item_key: itemKey, village_id: villageID), token: token)
    }

    // MARK: - Market

    private struct ResourceOfferBody: Encodable {
        let offer_resource: String
        let offer_amount: Int
        let request_resource: String
        let request_amount: Int
    }
    private struct ItemOfferBody: Encodable {
        let item_key: String
        let price_resource: String
        let price_amount: Int
    }

    func fetchMarket(villageID: Int, token: String) async throws -> MarketDetail {
        var request = try makeRequest(path: "/api/villages/\(villageID)/market", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)

        guard let decoded = try? decoder.decode(MarketDetail.self, from: data) else {
            throw APIError.decoding
        }
        return decoded
    }

    /// Shared plumbing for every market mutation below — all of them just report "did it work",
    /// same pattern as Hero's postHeroAction.
    private func postMarketAction(path: String, body: Encodable?, method: String, token: String) async throws {
        var request = try makeRequest(path: path, method: method)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body { request.httpBody = try JSONEncoder().encode(body) }

        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    func createResourceOffer(villageID: Int, offerResource: String, offerAmount: Int, requestResource: String, requestAmount: Int, token: String) async throws {
        let body = ResourceOfferBody(offer_resource: offerResource, offer_amount: offerAmount, request_resource: requestResource, request_amount: requestAmount)
        try await postMarketAction(path: "/api/villages/\(villageID)/market", body: body, method: "POST", token: token)
    }

    func acceptResourceOffer(villageID: Int, offerID: Int, token: String) async throws {
        try await postMarketAction(path: "/api/villages/\(villageID)/market/\(offerID)/accept", body: nil, method: "POST", token: token)
    }

    func cancelResourceOffer(villageID: Int, offerID: Int, token: String) async throws {
        try await postMarketAction(path: "/api/villages/\(villageID)/market/\(offerID)", body: nil, method: "DELETE", token: token)
    }

    func createItemOffer(villageID: Int, itemKey: String, priceResource: String, priceAmount: Int, token: String) async throws {
        let body = ItemOfferBody(item_key: itemKey, price_resource: priceResource, price_amount: priceAmount)
        try await postMarketAction(path: "/api/villages/\(villageID)/market/items", body: body, method: "POST", token: token)
    }

    func acceptItemOffer(villageID: Int, offerID: Int, token: String) async throws {
        try await postMarketAction(path: "/api/villages/\(villageID)/market/items/\(offerID)/accept", body: nil, method: "POST", token: token)
    }

    func cancelItemOffer(villageID: Int, offerID: Int, token: String) async throws {
        try await postMarketAction(path: "/api/villages/\(villageID)/market/items/\(offerID)", body: nil, method: "DELETE", token: token)
    }

    // MARK: - Alliance

    private struct AlliancesResponse: Codable { let alliances: [AllianceSummary] }
    private struct AllianceResponse: Codable { let alliance: AllianceDetail }
    private struct CreateAllianceBody: Encodable { let name: String; let tag: String; let description: String? }

    func fetchAlliances(token: String) async throws -> [AllianceSummary] {
        var request = try makeRequest(path: "/api/alliances", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(AlliancesResponse.self, from: data) else { throw APIError.decoding }
        return decoded.alliances
    }

    func fetchAlliance(id: Int, token: String) async throws -> AllianceDetail {
        var request = try makeRequest(path: "/api/alliances/\(id)", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(AllianceResponse.self, from: data) else { throw APIError.decoding }
        return decoded.alliance
    }

    func createAlliance(name: String, tag: String, description: String?, token: String) async throws {
        var request = try makeRequest(path: "/api/alliances", method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(CreateAllianceBody(name: name, tag: tag, description: description))
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    func joinAlliance(id: Int, token: String) async throws {
        var request = try makeRequest(path: "/api/alliances/\(id)/join", method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    func leaveAlliance(token: String) async throws {
        var request = try makeRequest(path: "/api/alliances/leave", method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    // MARK: - Shop

    private struct BuyCrystalsBody: Encodable { let package_id: Int }

    func fetchShop(token: String) async throws -> ShopDetail {
        var request = try makeRequest(path: "/api/shop", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(ShopDetail.self, from: data) else { throw APIError.decoding }
        return decoded
    }

    private func postShopAction(path: String, body: Encodable?, token: String) async throws {
        var request = try makeRequest(path: path, method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body { request.httpBody = try JSONEncoder().encode(body) }
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    func purchaseShopItem(id: Int, token: String) async throws {
        try await postShopAction(path: "/api/shop/items/\(id)/buy", body: nil, token: token)
    }

    func buyCrystals(packageID: Int, token: String) async throws {
        try await postShopAction(path: "/api/shop/buy-crystals", body: BuyCrystalsBody(package_id: packageID), token: token)
    }

    func unlockPlusQueue(token: String) async throws {
        try await postShopAction(path: "/api/shop/unlock-plus-queue", body: nil, token: token)
    }

    func unlockPlusQueueTemporary(token: String) async throws {
        try await postShopAction(path: "/api/shop/unlock-plus-queue-temp", body: nil, token: token)
    }

    // MARK: - Rally point / training

    private struct SendTroopsBody: Encodable { let type: String; let target_x: Int; let target_y: Int; let units: [String: Int] }
    private struct TrainBody: Encodable { let unit_key: String; let count: Int }

    func fetchRallyPoint(villageID: Int, token: String) async throws -> RallyPointDetail {
        var request = try makeRequest(path: "/api/villages/\(villageID)/rally-point", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(RallyPointDetail.self, from: data) else { throw APIError.decoding }
        return decoded
    }

    func sendTroops(villageID: Int, type: String, targetX: Int, targetY: Int, units: [String: Int], token: String) async throws {
        var request = try makeRequest(path: "/api/villages/\(villageID)/rally-point/send", method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(SendTroopsBody(type: type, target_x: targetX, target_y: targetY, units: units))
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    func fetchTraining(villageID: Int, building: String, token: String) async throws -> TrainingDetail {
        var request = try makeRequest(path: "/api/villages/\(villageID)/train/\(building)", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(TrainingDetail.self, from: data) else { throw APIError.decoding }
        return decoded
    }

    func train(villageID: Int, building: String, unitKey: String, count: Int, token: String) async throws {
        var request = try makeRequest(path: "/api/villages/\(villageID)/train/\(building)", method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(TrainBody(unit_key: unitKey, count: count))
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    // MARK: - Commanders

    private struct SquadBody: Encodable { let commander_ids: [Int] }

    func fetchCommanders(token: String) async throws -> CommanderCollection {
        var request = try makeRequest(path: "/api/commanders", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(CommanderCollection.self, from: data) else { throw APIError.decoding }
        return decoded
    }

    func recruitCommander(token: String) async throws {
        var request = try makeRequest(path: "/api/commanders/recruit", method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    func setCommanderSquad(commanderIDs: [Int], token: String) async throws {
        var request = try makeRequest(path: "/api/commanders/squad", method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(SquadBody(commander_ids: commanderIDs))
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    // MARK: - Arena

    func fetchArena(token: String) async throws -> ArenaDetail {
        var request = try makeRequest(path: "/api/arena", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(ArenaDetail.self, from: data) else { throw APIError.decoding }
        return decoded
    }

    func fightArena(token: String) async throws -> ArenaFightResult {
        var request = try makeRequest(path: "/api/arena/fight", method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(ArenaFightResult.self, from: data) else { throw APIError.decoding }
        return decoded
    }

    // MARK: - Backpack

    private struct UseItemBody: Encodable { let item_key: String; let village_id: Int }

    func fetchBackpack(token: String) async throws -> BackpackResponse {
        var request = try makeRequest(path: "/api/backpack", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(BackpackResponse.self, from: data) else { throw APIError.decoding }
        return decoded
    }

    func useBackpackItem(itemKey: String, villageID: Int, token: String) async throws {
        var request = try makeRequest(path: "/api/backpack/use", method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(UseItemBody(item_key: itemKey, village_id: villageID))
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    // MARK: - Reports

    private struct ReportsResponse: Codable { let reports: [ReportSummary] }
    private struct ReportResponse: Decodable { let report: ReportDetail }

    func fetchReports(token: String) async throws -> [ReportSummary] {
        var request = try makeRequest(path: "/api/reports", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(ReportsResponse.self, from: data) else { throw APIError.decoding }
        return decoded.reports
    }

    func fetchReport(id: Int, token: String) async throws -> ReportDetail {
        var request = try makeRequest(path: "/api/reports/\(id)", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(ReportResponse.self, from: data) else { throw APIError.decoding }
        return decoded.report
    }

    func deleteReport(id: Int, token: String) async throws {
        var request = try makeRequest(path: "/api/reports/\(id)", method: "DELETE")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    // MARK: - Messages

    private struct MessagesResponse: Codable { let messages: [MessageSummary] }
    private struct EventsResponse: Codable { let messages: [GameEventSummary] }
    private struct MessageDetailResponse: Codable { let message: MessageDetail }
    private struct SendMessageBody: Encodable { let recipient: String; let subject: String; let body: String }

    func fetchMessages(box: String, token: String) async throws -> [MessageSummary] {
        var request = try makeRequest(path: "/api/messages?box=\(box)", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(MessagesResponse.self, from: data) else { throw APIError.decoding }
        return decoded.messages
    }

    func fetchEvents(token: String) async throws -> [GameEventSummary] {
        var request = try makeRequest(path: "/api/messages?box=events", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(EventsResponse.self, from: data) else { throw APIError.decoding }
        return decoded.messages
    }

    func fetchMessage(id: Int, token: String) async throws -> MessageDetail {
        var request = try makeRequest(path: "/api/messages/\(id)", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(MessageDetailResponse.self, from: data) else { throw APIError.decoding }
        return decoded.message
    }

    func sendMessage(recipient: String, subject: String, body: String, token: String) async throws {
        var request = try makeRequest(path: "/api/messages", method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(SendMessageBody(recipient: recipient, subject: subject, body: body))
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    func markAllMessagesRead(token: String) async throws {
        var request = try makeRequest(path: "/api/messages/read-all", method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    func deleteMessage(id: Int, token: String) async throws {
        var request = try makeRequest(path: "/api/messages/\(id)", method: "DELETE")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    // MARK: - Research / tech tree

    private struct StartResearchBody: Encodable { let key: String; let village_id: Int }

    func fetchResearch(token: String) async throws -> ResearchDetail {
        var request = try makeRequest(path: "/api/research", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(ResearchDetail.self, from: data) else { throw APIError.decoding }
        return decoded
    }

    func startResearch(key: String, villageID: Int, token: String) async throws {
        var request = try makeRequest(path: "/api/research/start", method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(StartResearchBody(key: key, village_id: villageID))
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    func fetchTechTree(villageID: Int?, token: String) async throws -> TechTreeResponse {
        var path = "/api/tech-tree"
        if let villageID { path += "?village_id=\(villageID)" }
        var request = try makeRequest(path: path, method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(TechTreeResponse.self, from: data) else { throw APIError.decoding }
        return decoded
    }

    // MARK: - Statistics / Quests / Help

    func fetchStatistics(token: String) async throws -> StatisticsResponse {
        var request = try makeRequest(path: "/api/statistics", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(StatisticsResponse.self, from: data) else { throw APIError.decoding }
        return decoded
    }

    private struct ClaimQuestBody: Encodable { let village_id: Int? }

    func fetchQuests(villageID: Int?, token: String) async throws -> QuestStatus {
        var path = "/api/quests"
        if let villageID { path += "?village_id=\(villageID)" }
        var request = try makeRequest(path: path, method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(QuestStatus.self, from: data) else { throw APIError.decoding }
        return decoded
    }

    func claimQuest(villageID: Int?, token: String) async throws {
        var request = try makeRequest(path: "/api/quests/claim", method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(ClaimQuestBody(village_id: villageID))
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    func claimQuestTail(villageID: Int?, token: String) async throws {
        var request = try makeRequest(path: "/api/quests/claim-tail", method: "POST")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(ClaimQuestBody(village_id: villageID))
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
    }

    func fetchHelp(token: String) async throws -> HelpContent {
        var request = try makeRequest(path: "/api/help", method: "GET")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        try Self.checkStatus(response, data: data, decoder: decoder)
        guard let decoded = try? decoder.decode(HelpContent.self, from: data) else { throw APIError.decoding }
        return decoded
    }

    func logout(token: String) async {
        guard var request = try? makeRequest(path: "/api/logout", method: "POST") else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // Best-effort: if this fails (offline, server already forgot the token, ...) we still
        // drop the local token in AuthSession.logout() right after calling this.
        _ = try? await perform(request)
    }

    // A handful of call sites (fetchWorldMap, fetchMessages, ...) pass a "path?x=1&y=2"-style
    // string, expecting a real query string on the request. `base.appendingPathComponent(path)`
    // used to be given that whole string as-is — appendingPathComponent treats its argument as
    // ONE literal path segment, so it percent-encodes the "?" and "&" right into the URL PATH
    // (e.g. "/api/map%3Fx=0&y=0") instead of treating them as query syntax. Laravel's router
    // then has nothing matching that literal path and 404s — exactly the reported "the route
    // api/map%3Fx=0&y=0 could not be found". Splitting the query off first and attaching it via
    // URLComponents (which understands "?"/"&" as query syntax, not path characters) fixes every
    // caller that builds its path this way, not just the world map.
    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let base = baseURL else { throw APIError.invalidServerURL }

        let parts = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let pathOnly = String(parts[0])
        let queryOnly = parts.count > 1 ? String(parts[1]) : nil

        guard var components = URLComponents(url: base.appendingPathComponent(pathOnly), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidServerURL
        }
        if let queryOnly {
            components.percentEncodedQuery = queryOnly
        }
        guard let url = components.url else { throw APIError.invalidServerURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
    }

    private static func checkStatus(_ response: URLResponse, data: Data, decoder: JSONDecoder) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        default:
            if let decoded = try? decoder.decode(ErrorResponse.self, from: data), let message = decoded.message {
                throw APIError.server(message: message)
            }
            throw APIError.server(message: "Сервер вернул ошибку (\(http.statusCode)).")
        }
    }
}