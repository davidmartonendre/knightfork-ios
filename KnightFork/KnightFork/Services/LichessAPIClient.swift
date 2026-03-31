import Foundation

/// Client for Lichess game import API.
actor LichessAPIClient {
    static let shared = LichessAPIClient()

    private let session = URLSession.shared

    /// Fetch recent games for a username.
    func fetchGames(username: String, max: Int = 100, since: Date? = nil) async throws -> String {
        var components = URLComponents(string: "https://lichess.org/api/games/user/\(username)")!
        var queryItems = [
            URLQueryItem(name: "max", value: "\(max)"),
            URLQueryItem(name: "pgnInJson", value: "false")
        ]
        if let since {
            queryItems.append(URLQueryItem(name: "since", value: "\(Int(since.timeIntervalSince1970 * 1000))"))
        }
        components.queryItems = queryItems

        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue("application/x-chess-pgn", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Fetch a single game by ID.
    func fetchGame(id: String) async throws -> String {
        let url = URL(string: "https://lichess.org/game/export/\(id)")!
        var request = URLRequest(url: url)
        request.setValue("application/x-chess-pgn", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)
        return String(data: data, encoding: .utf8) ?? ""
    }
}
