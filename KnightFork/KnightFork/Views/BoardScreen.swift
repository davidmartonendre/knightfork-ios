import SwiftUI
import ChessKit

/// Main board screen for free play / analysis.
struct BoardScreen: View {
    @State private var viewModel = BoardViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Board
            ChessBoardView(viewModel: viewModel)
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 4)

            // Status
            boardStatusView

            // Navigation
            NavigationBar(viewModel: viewModel) {
                viewModel.isFlipped.toggle()
            }

            Spacer(minLength: 0)
        }
        .background(Color(.systemGroupedBackground))
        .disableSwipeBack()
    }

    @ViewBuilder
    private var boardStatusView: some View {
        HStack {
            switch viewModel.boardState {
            case .checkmate(let color):
                let winner = color == .white ? "Black" : "White"
                Label("\(winner) wins by checkmate", systemImage: "trophy.fill")
                    .foregroundStyle(.orange)
            case .check:
                Label("Check", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            case .draw(let reason):
                let text: String = {
                    switch reason {
                    case .stalemate: return "Draw by stalemate"
                    case .fiftyMoves: return "Draw by 50-move rule"
                    case .repetition: return "Draw by repetition"
                    case .insufficientMaterial: return "Draw by insufficient material"
                    case .agreement: return "Draw by agreement"
                    }
                }()
                Label(text, systemImage: "equal.circle.fill")
                    .foregroundStyle(.secondary)
            case .promotion:
                Label("Choose promotion piece", systemImage: "arrow.up.circle.fill")
                    .foregroundStyle(.blue)
            case .active:
                let side = viewModel.sideToMove == .white ? "White" : "Black"
                Text("\(side) to move")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .padding(.vertical, 6)
    }
}
