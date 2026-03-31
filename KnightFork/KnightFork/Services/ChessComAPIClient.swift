import Foundation

/// Response from Chess.com game archives.
struct ChessComArchiveResponse: Codable {
    let archives: [String]
}

struct ChessComGamesResponse: Codable {
    let games: [ChessComGame]
}

struct ChessComGame: Codable {
    let pgn: String?
}

/// Client for Chess.com game import API.
actor ChessComAPIClient {
    static let shared = ChessComAPIClient()

    private let session = URLSession.shared

    /// Fetch games for a username from a specific month.
    func fetchGames(username: String, year: Int, month: Int) async throws -> [String] {
        let monthStr = String(format: "%02d", month)
        let url = URL(string: "https://api.chess.com/pub/player/\(username)/games/\(year)/\(monthStr)")!

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(ChessComGamesResponse.self, from: data)
        return response.games.compactMap(\.pgn)
    }

    /// Fetch all available archive months.
    func fetchArchives(username: String) async throws -> [String] {
        let url = URL(string: "https://api.chess.com/pub/player/\(username)/games/archives")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(ChessComArchiveResponse.self, from: data)
        return response.archives
    }
}
