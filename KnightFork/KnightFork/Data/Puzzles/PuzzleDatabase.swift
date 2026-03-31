import Foundation
import ChessKit
import OSLog

private let log = Logger(subsystem: "com.knightfork", category: "PuzzleDB")

/// A single puzzle from Lichess.
struct Puzzle: Identifiable, Codable {
    let id: String
    let fen: String           // Position BEFORE the setup move
    let moves: [String]       // UCI moves: first is opponent's setup, rest are solution
    let rating: Int
    let themes: [String]

    /// The setup move (opponent's last move before the puzzle starts).
    var setupMove: String? { moves.first }

    /// The solution moves the player must find (excludes setup move).
    var solutionMoves: [String] { Array(moves.dropFirst()) }
}

/// Difficulty levels for Lichess puzzle API.
enum PuzzleDifficulty: String, CaseIterable, Identifiable {
    case easiest, easier, normal, harder, hardest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easiest: return "Easiest (~800-1100)"
        case .easier:  return "Easier (~1100-1400)"
        case .normal:  return "Normal (~1400-1600)"
        case .harder:  return "Harder (~1600-1900)"
        case .hardest: return "Hardest (~1900-2400)"
        }
    }
}

/// Known puzzle themes from Lichess.
enum PuzzleThemeOption: String, CaseIterable, Identifiable {
    case mix
    case opening, middlegame, endgame
    case advancedPawn, attackingF2F7, capturingDefender
    case discoveredAttack, doubleCheck, exposedKing
    case fork, hangingPiece, kingsideAttack, pin
    case queensideAttack, sacrifice, skewer, trappedPiece
    case attraction, clearance, defensiveMove, deflection
    case interference, intermezzo, quietMove, xRayAttack, zugzwang
    case mate, mateIn1, mateIn2, mateIn3, mateIn4, mateIn5
    case anastasiaMate, arabianMate, backRankMate, bodenMate
    case doubleBishopMate, hookMate, smotheredMate
    case castling, enPassant, promotion, underPromotion
    case equality, advantage, crushing
    case oneMove, short, long, veryLong

    var id: String { rawValue }

    var displayName: String {
        if self == .mix { return "Random Mix" }
        let spaced = rawValue.replacingOccurrences(
            of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression
        )
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }

    var group: String {
        switch self {
        case .mix: return "General"
        case .opening, .middlegame, .endgame: return "Phase"
        case .mate, .mateIn1, .mateIn2, .mateIn3, .mateIn4, .mateIn5,
             .anastasiaMate, .arabianMate, .backRankMate, .bodenMate,
             .doubleBishopMate, .hookMate, .smotheredMate: return "Checkmate"
        case .fork, .pin, .skewer, .discoveredAttack, .doubleCheck,
             .attraction, .clearance, .deflection, .interference,
             .intermezzo, .xRayAttack, .sacrifice: return "Tactics"
        case .advancedPawn, .capturingDefender, .exposedKing,
             .hangingPiece, .kingsideAttack, .queensideAttack,
             .attackingF2F7, .trappedPiece, .defensiveMove,
             .quietMove, .zugzwang: return "Patterns"
        case .castling, .enPassant, .promotion, .underPromotion: return "Special Moves"
        case .equality, .advantage, .crushing: return "Advantage"
        case .oneMove, .short, .long, .veryLong: return "Length"
        }
    }
}

// MARK: - Lichess API Response Types

struct LichessPuzzleBatch: Codable {
    let puzzles: [LichessPuzzleEntry]
}

struct LichessPuzzleEntry: Codable {
    let puzzle: LichessPuzzleData
    let game: LichessGameData
}

struct LichessPuzzleData: Codable {
    let id: String
    let initialPly: Int
    let plays: Int
    let rating: Int
    let solution: [String]
    let themes: [String]
}

struct LichessGameData: Codable {
    let id: String
    let pgn: String
    let clock: String?
}

// MARK: - Puzzle Fetcher

/// Fetches puzzles from the Lichess API.
final class PuzzleDatabase {
    static let shared = PuzzleDatabase()

    private let session: URLSession
    private var cache: [Puzzle] = []

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    /// Fetch a batch of puzzles from Lichess.
    func fetchBatch(
        theme: PuzzleThemeOption = .mix,
        difficulty: PuzzleDifficulty = .normal,
        count: Int = 30
    ) async throws -> [Puzzle] {
        let angle = theme.rawValue
        let urlString = "https://lichess.org/api/puzzle/batch/\(angle)?nb=\(min(count, 50))&difficulty=\(difficulty.rawValue)"

        guard let url = URL(string: urlString) else {
            throw PuzzleError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        log.info("Fetching puzzles: \(urlString)")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            log.error("Puzzle API returned \(code)")
            throw PuzzleError.apiError(code)
        }

        let batch = try JSONDecoder().decode(LichessPuzzleBatch.self, from: data)
        let puzzles = batch.puzzles.compactMap { convertEntry($0) }

        log.info("Fetched \(puzzles.count) puzzles")
        cache.append(contentsOf: puzzles)
        return puzzles
    }

    /// Fetch the daily puzzle.
    func fetchDaily() async throws -> Puzzle {
        guard let url = URL(string: "https://lichess.org/api/puzzle/daily") else {
            throw PuzzleError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)
        let entry = try JSONDecoder().decode(LichessPuzzleEntry.self, from: data)

        guard let puzzle = convertEntry(entry) else {
            throw PuzzleError.missingData
        }
        return puzzle
    }

    /// Get next puzzle from cache, or fetch more if empty.
    func nextPuzzle(
        theme: PuzzleThemeOption = .mix,
        difficulty: PuzzleDifficulty = .normal
    ) async throws -> Puzzle {
        if cache.isEmpty {
            _ = try await fetchBatch(theme: theme, difficulty: difficulty)
        }
        guard !cache.isEmpty else {
            throw PuzzleError.noPuzzles
        }
        return cache.removeFirst()
    }

    func clearCache() { cache.removeAll() }
    var cachedCount: Int { cache.count }

    // MARK: - PGN → FEN Conversion

    /// Convert a Lichess API entry to our Puzzle model by replaying the PGN.
    private func convertEntry(_ entry: LichessPuzzleEntry) -> Puzzle? {
        let pgnMoves = entry.game.pgn.split(separator: " ").map(String.init)
        let ply = entry.puzzle.initialPly

        // Replay PGN moves up to initialPly to get the FEN
        var game = Game()
        var currentIdx = game.startingIndex

        for (i, san) in pgnMoves.enumerated() {
            if i >= ply { break }
            currentIdx = game.make(move: san, from: currentIdx)
        }

        guard let position = game.positions[currentIdx] else {
            log.error("Failed to replay PGN for puzzle \(entry.puzzle.id)")
            return nil
        }

        return Puzzle(
            id: entry.puzzle.id,
            fen: position.fen,
            moves: entry.puzzle.solution,
            rating: entry.puzzle.rating,
            themes: entry.puzzle.themes
        )
    }
}

enum PuzzleError: LocalizedError {
    case invalidURL
    case apiError(Int)
    case missingData
    case noPuzzles

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid puzzle URL"
        case .apiError(let code): return "Lichess returned error \(code)"
        case .missingData: return "Puzzle data incomplete"
        case .noPuzzles: return "No puzzles available"
        }
    }
}
