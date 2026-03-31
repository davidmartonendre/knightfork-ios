import Foundation

/// Tablebase probe result for a position.
struct TablebaseResponse: Codable {
    let category: String        // "win", "loss", "draw", etc.
    let dtz: Int?               // Distance to zeroing
    let moves: [TablebaseMove]
}

struct TablebaseMove: Codable, Identifiable {
    let uci: String
    let san: String
    let category: String
    let dtz: Int?

    var id: String { uci }

    var resultText: String {
        switch category {
        case "win": return dtz.map { "Win in \(abs($0))" } ?? "Win"
        case "loss": return dtz.map { "Loss in \(abs($0))" } ?? "Loss"
        case "draw", "blessed-loss", "cursed-win": return "Draw"
        default: return category
        }
    }
}

/// Client for Lichess tablebase API (7-piece endgames).
actor TablebaseClient {
    static let shared = TablebaseClient()

    private let session = URLSession.shared
    private var cache: [String: TablebaseResponse] = [:]

    func probe(fen: String) async throws -> TablebaseResponse {
        if let cached = cache[fen] { return cached }

        var components = URLComponents(string: "https://tablebase.lichess.ovh/standard")!
        components.queryItems = [URLQueryItem(name: "fen", value: fen)]

        guard let url = components.url else { throw URLError(.badURL) }

        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(TablebaseResponse.self, from: data)
        cache[fen] = response
        return response
    }

    /// Count pieces in a FEN string.
    static func pieceCount(fen: String) -> Int {
        let board = fen.split(separator: " ").first ?? ""
        return board.filter { $0.isLetter }.count
    }
}
