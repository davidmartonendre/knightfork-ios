import SwiftUI
import ChessKit

/// Shows the Lichess daily puzzle.
struct DailyPuzzleView: View {
    @State private var viewModel = PuzzleViewModel()
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("Loading daily puzzle...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Retry") { loadDaily() }
                        .buttonStyle(.borderedProminent)
                }
                Spacer()
            } else {
                // Info bar
                if let puzzle = viewModel.currentPuzzle {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text("Daily Puzzle")
                                .font(.subheadline.weight(.medium))
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.fill")
                                .font(.caption)
                            Text("\(puzzle.rating)")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                ChessBoardView(viewModel: viewModel.boardViewModel)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, 4)
                    .allowsHitTesting(viewModel.state == .ready)

                // Status
                statusView

                Spacer(minLength: 0)
            }
        }
        .background(Color(.systemGroupedBackground))
        .disableSwipeBack()
        .navigationTitle("Daily Puzzle")
        .navigationBarTitleDisplayMode(.inline)
        .task { loadDaily() }
        .onChange(of: viewModel.boardViewModel.currentIndex) { old, new in
            guard viewModel.state == .ready else { return }
            let advanced = new.number > old.number ||
                (new.number == old.number && old.color == .white && new.color == .black) ||
                (new.number == old.number + 1 && old.color == .black && new.color == .white)
            if advanced {
                if let move = viewModel.boardViewModel.game.moves[new] {
                    viewModel.playerMoved(from: move.start, to: move.end)
                }
            }
        }
    }

    private func loadDaily() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let puzzle = try await PuzzleDatabase.shared.fetchDaily()
                viewModel.currentPuzzle = puzzle
                viewModel.attempted += 1
                // Setup position
                if let position = Position(fen: puzzle.fen) {
                    let game = Game(startingWith: position)
                    viewModel.boardViewModel.loadGame(game)
                    let playerColor: Piece.Color = position.sideToMove == .white ? .black : .white
                    viewModel.boardViewModel.interactionMode = .play(as: playerColor)
                    viewModel.boardViewModel.isFlipped = playerColor == .black

                    if let setupUCI = puzzle.setupMove, setupUCI.count >= 4 {
                        try? await Task.sleep(for: .milliseconds(300))
                        let from = Square(String(setupUCI.prefix(2)))
                        let to = Square(String(setupUCI.dropFirst(2).prefix(2)))
                        viewModel.boardViewModel.makeMove(from: from, to: to)
                    }
                    viewModel.state = .ready
                }
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.state {
        case .ready:
            HStack {
                Text("Your turn — find the best move")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { viewModel.showHint() } label: {
                    Image(systemName: "lightbulb")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                }
            }
            .padding()

        case .correct:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Correct! Keep going...")
                    .foregroundStyle(.green)
            }
            .padding()

        case .wrong:
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("Not quite — try again")
                        .foregroundStyle(.red)
                }
                HStack(spacing: 12) {
                    Button("Hint") { viewModel.showHint() }
                        .buttonStyle(.bordered)
                    Button("Show Solution") { viewModel.showSolution() }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                }
            }
            .padding()

        case .solved:
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("Daily puzzle solved!")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
            .padding()

        case .failed:
            Text("Solution shown")
                .foregroundStyle(.secondary)
                .padding()

        default:
            EmptyView()
        }
    }
}
