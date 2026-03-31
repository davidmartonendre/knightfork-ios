import Foundation

/// SM-2 spaced repetition algorithm.
struct SpacedRepetition {

    /// Update a training progress entry based on response quality.
    /// Quality: 1 = again, 2 = hard, 3 = good, 4 = easy
    static func update(
        ease: Double,
        interval: Int,
        reviewCount: Int,
        quality: Int
    ) -> (newEase: Double, newInterval: Int) {
        let q = Double(max(1, min(4, quality)))
        // Map 1-4 to SM-2's 0-5 scale: 1→0, 2→2, 3→3, 4→5
        let sm2q: Double
        switch quality {
        case 1: sm2q = 0
        case 2: sm2q = 2
        case 3: sm2q = 3
        default: sm2q = 5
        }

        var newEase = ease + (0.1 - (5 - sm2q) * (0.08 + (5 - sm2q) * 0.02))
        newEase = max(1.3, newEase) // Minimum ease factor

        let newInterval: Int
        if quality < 2 {
            // Reset on failure
            newInterval = 1
        } else if reviewCount == 0 {
            newInterval = 1
        } else if reviewCount == 1 {
            newInterval = 6
        } else {
            newInterval = Int(round(Double(interval) * newEase))
        }

        return (newEase, newInterval)
    }
}
