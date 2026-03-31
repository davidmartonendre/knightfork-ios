import SwiftUI
import ChessKit

/// Opening explorer panel showing move statistics.
struct ExplorerPanel: View {
    let moves: [ExplorerMove]
    let opening: ExplorerOpening?
    let isLoading: Bool
    let isTablebase: Bool
    let tablebaseMoves: [TablebaseMove]
    var source: ExplorerSource
    var onSourceChanged: ((ExplorerSource) -> Void)?
    var onMoveTapped: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Source picker + opening name
            HStack {
                Picker("Source", selection: Binding(
                    get: { source },
                    set: { onSourceChanged?($0) }
                )) {
                    ForEach(ExplorerSource.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)

                Spacer()

                if let name = opening?.name {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)

            if isLoading {
                HStack {
                    ProgressView().scaleEffect(0.7)
                    Text("Loading...").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
            } else if isTablebase {
                // Tablebase view
                ForEach(tablebaseMoves) { move in
                    tablebaseRow(move)
                }
            } else if moves.isEmpty {
                Text("No games found for this position")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            } else {
                // Explorer moves
                ForEach(moves) { move in
                    explorerRow(move)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func explorerRow(_ move: ExplorerMove) -> some View {
        Button {
            onMoveTapped?(move.san)
        } label: {
            HStack(spacing: 4) {
                Text(move.san)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .frame(width: 50, alignment: .leading)

                Text("\(move.totalGames)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 45, alignment: .trailing)

                // Win/draw/loss bar
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        Rectangle().fill(.white)
                            .frame(width: geo.size.width * move.whiteWinRate)
                        Rectangle().fill(.gray)
                            .frame(width: geo.size.width * move.drawRate)
                        Rectangle().fill(.black)
                            .frame(width: geo.size.width * move.blackWinRate)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                .frame(height: 10)

                Text(String(format: "%.0f%%", move.whiteWinRate * 100))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 35, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    private func tablebaseRow(_ move: TablebaseMove) -> some View {
        Button {
            onMoveTapped?(move.san)
        } label: {
            HStack {
                Text(move.san)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .frame(width: 50, alignment: .leading)
                Text(move.resultText)
                    .font(.system(size: 12))
                    .foregroundStyle(tablebaseColor(move.category))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    private func tablebaseColor(_ category: String) -> Color {
        switch category {
        case "win": return .green
        case "loss": return .red
        default: return .secondary
        }
    }
}
