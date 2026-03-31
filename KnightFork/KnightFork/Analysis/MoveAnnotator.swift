import Foundation
import ChessKit

/// Annotation glyph for a move based on win-probability loss.
enum MoveAnnotation: String, CaseIterable {
    case brilliant = "!!"
    case good = "!"
    case interesting = "!?"
    case dubious = "?!"
    case mistake = "?"
    case blunder = "??"
    case none = ""

    var assessment: Move.Assessment {
        switch self {
        case .brilliant: return .brilliant
        case .good: return .good
        case .interesting: return .interesting
        case .dubious: return .dubious
        case .mistake: return .mistake
        case .blunder: return .blunder
        case .none: return .null
        }
    }
}

/// Assigns annotation glyphs based on win-probability loss.
struct MoveAnnotator {

    /// Annotate a move based on win-probability loss.
    static func annotate(winProbLoss: Double, isSacrifice: Bool = false, isOnlyGoodMove: Bool = false) -> MoveAnnotation {
        // Brilliant: sacrifice that is the only sound move
        if isSacrifice && isOnlyGoodMove && winProbLoss < 5 {
            return .brilliant
        }
        // Good: only sound move that punishes opponent's mistake
        if isOnlyGoodMove && winProbLoss < 2 {
            return .good
        }
        // Interesting: sacrifice that is not the only sound move
        if isSacrifice && winProbLoss < 5 {
            return .interesting
        }

        // Standard thresholds
        if winProbLoss >= 20 { return .blunder }
        if winProbLoss >= 10 { return .mistake }
        if winProbLoss >= 5 { return .dubious }

        return .none
    }
}
