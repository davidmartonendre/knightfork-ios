import Foundation
import ChessKit

/// Exports games to PGN format.
struct PGNExporter {

    /// Convert a GameRecord's PGN to a shareable string.
    static func export(record: GameRecord) -> String {
        // If we have annotated PGN from analysis, prefer that
        return record.annotatedPGN ?? record.pgn
    }

    /// Convert a Game object to PGN string.
    static func export(game: Game) -> String {
        return PGNParser.convert(game: game)
    }

    /// Export the current board position as a FEN string.
    static func exportFEN(from viewModel: BoardViewModel) -> String {
        return viewModel.currentPosition.fen
    }
}
