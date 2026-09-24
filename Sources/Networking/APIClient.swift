private struct RegisterBody: Encodable {
    let name: String?
    let tribe: String
    let device_name: String
    let game_center_player_id: String
}

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