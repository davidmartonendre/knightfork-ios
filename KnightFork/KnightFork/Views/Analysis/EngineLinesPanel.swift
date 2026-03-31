import SwiftUI
import ChessKit

/// Displays multi-PV engine lines in real-time.
struct EngineLinesPanel: View {
    let lines: [EngineLine]
    let isSearching: Bool
    var sideToMove: Piece.Color = .white
    var onLineTapped: ((EngineLine) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if lines.isEmpty && isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Analyzing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            } else {
                ForEach(lines) { line in
                    EngineLineRow(line: line, sideToMove: sideToMove)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onLineTapped?(line)
                        }
                }
            }
        }
    }
}

struct EngineLineRow: View {
    let line: EngineLine
    var sideToMove: Piece.Color = .white

    /// Normalize to white's perspective.
    private var normalizedScore: EngineScore {
        if sideToMove == .white { return line.score }
        switch line.score {
        case .cp(let cp): return .cp(-cp)
        case .mate(let n): return .mate(-n)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            // Line number badge
            Text("\(line.id)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(badgeColor)
                .clipShape(Circle())

            // Eval (normalized to white's perspective)
            Text(normalizedScore.displayString)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(evalColor)
                .frame(width: 52, alignment: .leading)

            // PV moves
            Text(pvText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            // Depth
            Text("d=\(line.depth)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }

    private var pvText: String {
        // Convert LAN moves (e2e4) to readable short format (e4, Nf3)
        line.pv.prefix(6).map { lanToShort($0) }.joined(separator: " ")
    }

    /// Convert LAN like "e2e4" to shorter "e4", "g1f3" to "Nf3" etc.
    /// This is approximate — full SAN conversion needs the board state.
    private func lanToShort(_ lan: String) -> String {
        guard lan.count >= 4 else { return lan }
        let to = String(lan.suffix(from: lan.index(lan.startIndex, offsetBy: 2)).prefix(2))
        // If there's a promotion char, append it
        if lan.count == 5 {
            let promo = lan.last!.uppercased()
            return "\(to)=\(promo)"
        }
        return to
    }

    private var evalColor: Color {
        switch normalizedScore {
        case .cp(let cp):
            if cp > 50 { return .green }
            if cp < -50 { return .red }
            return .primary
        case .mate(let n):
            return n > 0 ? .green : .red
        }
    }

    private var badgeColor: Color {
        switch line.id {
        case 1: return .green
        case 2: return .blue
        default: return .gray
        }
    }
}
