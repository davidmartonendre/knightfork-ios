import Foundation

/// Computes accuracy scores using centipawn-loss method.
struct AccuracyScorer {

    /// Win probability from centipawns using the Lichess formula.
    static func winProbability(cp: Double) -> Double {
        50.0 + 50.0 * (2.0 / (1.0 + exp(-0.00368208 * cp)) - 1.0)
    }

    /// Per-move accuracy from win-probability loss (Lichess exponential formula).
    /// wpLoss is in percentage points (0-100).
    static func moveAccuracy(winProbLoss: Double) -> Double {
        // Lichess formula: 103.1668 * exp(-0.04354 * wpLoss) - 3.1668
        // More realistic than linear — small losses still penalize significantly
        let raw = 103.1668 * exp(-0.04354 * winProbLoss) - 3.1668
        return max(0, min(100, raw))
    }

    /// Overall accuracy as average of per-move accuracies.
    static func overallAccuracy(perMoveAccuracies: [Double]) -> Double {
        guard !perMoveAccuracies.isEmpty else { return 100 }
        return perMoveAccuracies.reduce(0, +) / Double(perMoveAccuracies.count)
    }
}
