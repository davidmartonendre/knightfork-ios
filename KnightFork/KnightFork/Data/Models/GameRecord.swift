import Foundation
import SwiftData

/// Source of an imported game.
enum GameSource: String, Codable {
    case manual
    case pgn
    case lichess
    case chesscom
}

/// Analysis state of a game.
enum AnalysisState: String, Codable {
    case none
    case inProgress
    case complete
}

/// Persistent game record stored in SwiftData.
@Model
final class GameRecord {
    @Attribute(.unique) var id: UUID
    var white: String
    var black: String
    var date: Date
    var result: String          // "1-0", "0-1", "1/2-1/2", "*"
    var event: String
    var site: String
    var eco: String
    var pgn: String             // Full PGN text
    var timeControl: String
    var source: GameSource
    var sourceId: String        // External ID (Lichess game ID, etc.)
    var analysisState: AnalysisState
    var annotatedPGN: String?   // PGN with analysis annotations (after game report)
    var whiteElo: Int?
    var blackElo: Int?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        white: String = "?",
        black: String = "?",
        date: Date = Date(),
        result: String = "*",
        event: String = "",
        site: String = "",
        eco: String = "",
        pgn: String = "",
        timeControl: String = "",
        source: GameSource = .manual,
        sourceId: String = "",
        analysisState: AnalysisState = .none,
        whiteElo: Int? = nil,
        blackElo: Int? = nil
    ) {
        self.id = id
        self.white = white
        self.black = black
        self.date = date
        self.result = result
        self.event = event
        self.site = site
        self.eco = eco
        self.pgn = pgn
        self.timeControl = timeControl
        self.source = source
        self.sourceId = sourceId
        self.analysisState = analysisState
        self.whiteElo = whiteElo
        self.blackElo = blackElo
        self.createdAt = Date()
    }
}
