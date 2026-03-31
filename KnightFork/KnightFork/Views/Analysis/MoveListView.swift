import SwiftUI
import ChessKit

/// Inline move list display with tappable moves and variation support.
struct MoveListView: View {
    let game: Game
    let currentIndex: MoveTree.Index
    var onMoveTapped: ((MoveTree.Index) -> Void)?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(moveElements, id: \.id) { element in
                        switch element.kind {
                        case .moveNumber(let number):
                            Text("\(number).")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)

                        case .move(let index, let san, let assessment):
                            let isCurrent = index == currentIndex
                            Button {
                                onMoveTapped?(index)
                            } label: {
                                HStack(spacing: 1) {
                                    Text(san)
                                        .font(.system(size: 15, weight: isCurrent ? .bold : .regular, design: .monospaced))
                                    if let glyph = assessment {
                                        Text(glyph)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(assessmentColor(glyph))
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(isCurrent ? Color.accentColor.opacity(0.2) : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                            .id(element.id)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .onChange(of: currentIndex) { _, newIndex in
                withAnimation {
                    proxy.scrollTo("move-\(newIndex.number)-\(newIndex.color)-v\(newIndex.variation)", anchor: .center)
                }
            }
        }
        .frame(height: 44)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Build move elements

    private var moveElements: [MoveElement] {
        var elements: [MoveElement] = []
        let history = fullMoveHistory

        for index in history {
            guard let move = game.moves[index] else { continue }

            // Add move number for white moves
            let v = index.variation
            if index.color == .white {
                elements.append(MoveElement(
                    id: "num-\(index.number)-v\(v)",
                    kind: .moveNumber(index.number)
                ))
            }

            let assessment = move.assessment != .null ? move.assessment.notation : nil
            elements.append(MoveElement(
                id: "move-\(index.number)-\(index.color)-v\(v)",
                kind: .move(index: index, san: move.san, assessment: assessment)
            ))
        }

        return elements
    }

    private var fullMoveHistory: [MoveTree.Index] {
        // Get all moves from start to the furthest point we've explored
        let history = game.moves.history(for: currentIndex)
        let future = game.moves.future(for: currentIndex)
        return history + future
    }

    private func assessmentColor(_ glyph: String) -> Color {
        switch glyph {
        case "!!", "!": return .green
        case "??", "?": return .red
        case "!?", "?!": return .orange
        default: return .secondary
        }
    }
}

struct MoveElement {
    let id: String
    let kind: MoveElementKind
}

enum MoveElementKind {
    case moveNumber(Int)
    case move(index: MoveTree.Index, san: String, assessment: String?)
}
