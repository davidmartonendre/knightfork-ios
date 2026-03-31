import Foundation
import Observation
import ChessKitEngine

/// A single engine analysis line (one PV).
struct EngineLine: Identifiable, Equatable {
    let id: Int                // multipv index (1-based)
    var score: EngineScore
    var pv: [String]           // Principal variation in LAN/SAN
    var depth: Int
    var seldepth: Int
    var nodes: Int
    var nps: Int
    var time: Int              // milliseconds
}

/// Engine evaluation score.
enum EngineScore: Equatable {
    case cp(Double)            // Centipawns
    case mate(Int)             // Mate in N (positive = engine wins)

    /// Convert to display string (e.g., "+1.34", "-0.52", "M3", "-M7").
    var displayString: String {
        switch self {
        case .cp(let cp):
            let pawns = cp / 100.0
            let sign = pawns >= 0 ? "+" : ""
            return "\(sign)\(String(format: "%.2f", pawns))"
        case .mate(let n):
            return n > 0 ? "M\(n)" : "-M\(abs(n))"
        }
    }

    /// Win probability using Lichess formula.
    var winProbability: Double {
        switch self {
        case .cp(let cp):
            return 50.0 + 50.0 * (2.0 / (1.0 + exp(-0.00368208 * cp)) - 1.0)
        case .mate(let n):
            return n > 0 ? 100.0 : 0.0
        }
    }

    /// Eval bar fill fraction (0.0 = black winning, 1.0 = white winning).
    var evalBarFraction: Double {
        winProbability / 100.0
    }
}

/// Observable engine output state, updated from the response stream.
@Observable
final class EngineOutput {
    var lines: [EngineLine] = []
    var isSearching: Bool = false
    var currentDepth: Int = 0
    var bestMoveResult: String?   // The actual bestmove LAN from the engine
    var ponderMove: String?

    var bestLine: EngineLine? {
        lines.first
    }

    /// Update from an engine info response.
    func update(from info: EngineResponse.Info) {
        let multipv = info.multipv ?? 1
        let depth = info.depth ?? 0
        let score: EngineScore
        if let s = info.score {
            if let mate = s.mate {
                score = .mate(Int(mate))
            } else if let cp = s.cp {
                score = .cp(cp)
            } else {
                return
            }
        } else {
            return
        }

        let line = EngineLine(
            id: multipv,
            score: score,
            pv: info.pv ?? [],
            depth: depth,
            seldepth: info.seldepth ?? depth,
            nodes: info.nodes ?? 0,
            nps: info.nps ?? 0,
            time: info.time ?? 0
        )

        // Update the correct line slot
        if let idx = lines.firstIndex(where: { $0.id == multipv }) {
            lines[idx] = line
        } else {
            lines.append(line)
            lines.sort { $0.id < $1.id }
        }

        if depth > currentDepth {
            currentDepth = depth
        }
    }

    func reset() {
        lines.removeAll()
        currentDepth = 0
        isSearching = false
        bestMoveResult = nil
        ponderMove = nil
    }
}
