import Foundation

/// Response from the Lichess opening explorer API.
struct ExplorerResponse: Codable {
    let white: Int
    let draws: Int
    let black: Int
    let moves: [ExplorerMove]
    let opening: ExplorerOpening?
}

struct ExplorerMove: Codable, Identifiable {
    let uci: String
    let san: String
    let white: Int
    let draws: Int
    let black: Int
    let averageRating: Int?

    var id: String { uci }
    var totalGames: Int { white + draws + black }
    var whiteWinRate: Double { totalGames > 0 ? Double(white) / Double(totalGames) : 0 }
    var drawRate: Double { totalGames > 0 ? Double(draws) / Double(totalGames) : 0 }
    var blackWinRate: Double { totalGames > 0 ? Double(black) / Double(totalGames) : 0 }
}

struct ExplorerOpening: Codable {
    let eco: String?
    let name: String?
}

/// Data source for the explorer.
enum ExplorerSource: String, CaseIterable, Identifiable {
    case masters = "Masters"
    case lichess = "Lichess"

    var id: String { rawValue }
}

/// Client for the Lichess opening explorer API.
actor LichessExplorerClient {
    static let shared = LichessExplorerClient()

    private let session = URLSession.shared
    private var cache: [String: ExplorerResponse] = [:]
    private var lastRequestTime: Date = .distantPast
    private let minInterval: TimeInterval = 0.2  // Rate limit

    func explore(fen: String, source: ExplorerSource) async throws -> ExplorerResponse {
        let cacheKey = "\(source.rawValue):\(fen)"
        if let cached = cache[cacheKey] { return cached }

        // Rate limiting
        let elapsed = Date().timeIntervalSince(lastRequestTime)
        if elapsed < minInterval {
            try await Task.sleep(for: .milliseconds(Int((minInterval - elapsed) * 1000)))
        }

        let baseURL: String
        switch source {
        case .masters:
            baseURL = "https://explorer.lichess.ovh/masters"
        case .lichess:
            baseURL = "https://explorer.lichess.ovh/lichess"
        }

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "fen", value: fen),
            URLQueryItem(name: "topGames", value: "0"),
            URLQueryItem(name: "recentGames", value: "0")
        ]

        if source == .lichess {
            components.queryItems?.append(URLQueryItem(name: "ratings", value: "1600,1800,2000,2200,2500"))
            components.queryItems?.append(URLQueryItem(name: "speeds", value: "blitz,rapid,classical"))
        }

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        lastRequestTime = Date()
        let (data, response) = try await session.data(from: url)

        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(ExplorerResponse.self, from: data)
        cache[cacheKey] = decoded
        return decoded
    }
}
