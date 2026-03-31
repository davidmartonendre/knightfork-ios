import SwiftUI
import Charts
import ChessKit

/// Comprehensive game report view inspired by En Croissant.
struct ReportView: View {
    let report: GameReport
    let game: Game
    var onMoveTapped: ((Int) -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Accuracy + ACPL header
                accuracyHeader

                // Annotation counts table
                annotationTable

                // Eval graph
                evalGraphSection

                // Move-by-move list with annotations
                moveListSection
            }
            .padding()
        }
        .navigationTitle("Game Report")
    }

    // MARK: - Accuracy Header

    private var accuracyHeader: some View {
        HStack(spacing: 0) {
            // White
            VStack(spacing: 4) {
                Text("WHITE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f%%", report.whiteAccuracy))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(accuracyColor(report.whiteAccuracy))
                Text("Accuracy")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f ACPL", whiteACPL))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 60)

            // Black
            VStack(spacing: 4) {
                Text("BLACK")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f%%", report.blackAccuracy))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(accuracyColor(report.blackAccuracy))
                Text("Accuracy")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f ACPL", blackACPL))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Annotation Counts

    private var annotationTable: some View {
        VStack(spacing: 0) {
            ForEach(annotationRows, id: \.symbol) { row in
                HStack {
                    Text("\(row.whiteCount)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(row.whiteCount > 0 ? .primary : .tertiary)
                        .frame(width: 30, alignment: .trailing)

                    Spacer()

                    Text(row.symbol)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(row.color)
                        .frame(width: 24)

                    Text(row.name)
                        .font(.system(size: 13))
                        .foregroundStyle(row.color)
                        .frame(width: 80, alignment: .leading)

                    Spacer()

                    Text("\(row.blackCount)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(row.blackCount > 0 ? .primary : .tertiary)
                        .frame(width: 30, alignment: .leading)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 16)

                if row.symbol != "??" {
                    Divider().padding(.horizontal, 12)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Eval Graph

    private var evalGraphSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Evaluation")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            EvalGraphView(moves: report.moves, onMoveTapped: onMoveTapped)
                .frame(height: 120)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Move List

    private var moveListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Moves")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            // Inline annotated move text
            AnnotatedMoveText(moves: report.moves, onMoveTapped: onMoveTapped)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var whiteACPL: Double {
        let whiteMoves = report.whiteMoves
        guard !whiteMoves.isEmpty else { return 0 }
        let totalLoss = whiteMoves.reduce(0.0) { $0 + abs($1.scoreBefore - $1.scoreAfter) }
        return totalLoss / Double(whiteMoves.count)
    }

    private var blackACPL: Double {
        let blackMoves = report.blackMoves
        guard !blackMoves.isEmpty else { return 0 }
        let totalLoss = blackMoves.reduce(0.0) { $0 + abs($1.scoreBefore - $1.scoreAfter) }
        return totalLoss / Double(blackMoves.count)
    }

    private struct AnnotationRow {
        let symbol: String
        let name: String
        let color: Color
        let whiteCount: Int
        let blackCount: Int
    }

    private var annotationRows: [AnnotationRow] {
        let categories: [(MoveAnnotation, String, String, Color)] = [
            (.brilliant, "!!", "Brilliant", .cyan),
            (.good, "!", "Good", .green),
            (.interesting, "!?", "Interesting", .teal),
            (.dubious, "?!", "Dubious", .orange),
            (.mistake, "?", "Mistake", .orange),
            (.blunder, "??", "Blunder", .red),
        ]

        return categories.map { (ann, sym, name, color) in
            let wCount = report.whiteMoves.filter { $0.annotation == ann }.count
            let bCount = report.blackMoves.filter { $0.annotation == ann }.count
            return AnnotationRow(symbol: sym, name: name, color: color, whiteCount: wCount, blackCount: bCount)
        }
    }

    private func accuracyColor(_ accuracy: Double) -> Color {
        if accuracy >= 95 { return .green }
        if accuracy >= 85 { return .teal }
        if accuracy >= 70 { return .yellow }
        if accuracy >= 50 { return .orange }
        return .red
    }
}

/// Inline annotated move text (like En Croissant / Lichess).
struct AnnotatedMoveText: View {
    let moves: [MoveAnalysis]
    var onMoveTapped: ((Int) -> Void)?

    var body: some View {
        // Use a FlowLayout-like approach with wrapping text
        let elements = buildElements()

        WrappingHStack(elements: elements, onMoveTapped: onMoveTapped)
    }

    private func buildElements() -> [(id: Int, text: String, color: Color?, isMoveNum: Bool)] {
        var result: [(Int, String, Color?, Bool)] = []
        for move in moves {
            if move.color == .white {
                result.append((move.id * 10, "\(move.moveNumber).", nil, true))
            }

            let color = annotationColor(move.annotation)
            let text = move.annotation != .none ? "\(move.playedMove)\(move.annotation.rawValue)" : move.playedMove
            result.append((move.id * 10 + 1, text, color, false))
        }
        return result
    }

    private func annotationColor(_ ann: MoveAnnotation) -> Color? {
        switch ann {
        case .brilliant: return .cyan
        case .good: return .green
        case .interesting: return .teal
        case .dubious: return .orange
        case .mistake: return .orange
        case .blunder: return .red
        case .none: return nil
        }
    }
}

/// Simple wrapping horizontal stack for inline move text.
struct WrappingHStack: View {
    let elements: [(id: Int, text: String, color: Color?, isMoveNum: Bool)]
    var onMoveTapped: ((Int) -> Void)?

    var body: some View {
        concatenatedText
    }

    private var concatenatedText: Text {
        elements.reduce(Text("")) { result, elem in
            if elem.isMoveNum {
                return result + Text(" \(elem.text) ")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            } else if let color = elem.color {
                return result + Text("\(elem.text) ")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(color)
            } else {
                return result + Text("\(elem.text) ")
                    .font(.system(size: 13))
            }
        }
    }
}

/// Line chart showing evaluation across the game.
struct EvalGraphView: View {
    let moves: [MoveAnalysis]
    var onMoveTapped: ((Int) -> Void)?

    var body: some View {
        Chart {
            ForEach(moves) { move in
                AreaMark(
                    x: .value("Move", move.id),
                    yStart: .value("Zero", 0),
                    yEnd: .value("Eval", clampedEval(move.scoreBefore))
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [move.scoreBefore >= 0 ? .white.opacity(0.3) : .black.opacity(0.3), .clear],
                        startPoint: move.scoreBefore >= 0 ? .top : .bottom,
                        endPoint: move.scoreBefore >= 0 ? .bottom : .top
                    )
                )

                LineMark(
                    x: .value("Move", move.id),
                    y: .value("Eval", clampedEval(move.scoreBefore))
                )
                .foregroundStyle(Color.primary)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }

            RuleMark(y: .value("Equal", 0))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4]))
                .foregroundStyle(.secondary)
        }
        .chartYScale(domain: -6...6)
        .chartYAxis {
            AxisMarks(values: [-5, 0, 5]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)").font(.caption2)
                    }
                }
            }
        }
        .chartXAxis(.hidden)
    }

    private func clampedEval(_ cp: Double) -> Double {
        let pawns = cp / 100.0
        return max(-6, min(6, pawns))
    }
}
