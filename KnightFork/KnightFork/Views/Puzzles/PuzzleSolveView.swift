import SwiftUI
import ChessKit

/// The puzzle solving screen — shows one puzzle at a time with board interaction.
struct PuzzleSolveView: View {
    @State var viewModel = PuzzleViewModel()
    var initialDifficulty: PuzzleDifficulty = .normal
    var initialTheme: PuzzleThemeOption = .mix

    var body: some View {
        VStack(spacing: 0) {
            // Puzzle info bar
            puzzleInfoBar

            // Board
            ChessBoardView(viewModel: viewModel.boardViewModel)
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 4)
                .allowsHitTesting(viewModel.state == .ready)

            // Status + controls
            statusSection

            Spacer(minLength: 0)
        }
        .background(Color(.systemGroupedBackground))
        .disableSwipeBack()
        .navigationTitle("Puzzles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    if viewModel.streak > 1 {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                    Text("\(viewModel.solved)/\(viewModel.attempted)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            viewModel.difficulty = initialDifficulty
            viewModel.theme = initialTheme
            viewModel.loadNextPuzzle()
        }
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

    // MARK: - Subviews

    private var puzzleInfoBar: some View {
        HStack {
            if let puzzle = viewModel.currentPuzzle {
                // Rating badge
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                    Text("\(puzzle.rating)")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(ratingColor(puzzle.rating))

                // Themes
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(puzzle.themes.prefix(3), id: \.self) { theme in
                            Text(formatTheme(theme))
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer()

            // Flip board
            Button {
                viewModel.boardViewModel.isFlipped.toggle()
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.body)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var statusSection: some View {
        VStack(spacing: 12) {
            switch viewModel.state {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading puzzle...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()

            case .ready:
                HStack(spacing: 16) {
                    Text("Your turn — find the best move")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        viewModel.showHint()
                    } label: {
                        Image(systemName: "lightbulb")
                            .font(.title3)
                            .foregroundStyle(.yellow)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)

            case .correct:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Correct! Keep going...")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.green)
                }
                .padding()

            case .wrong:
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("Not quite — try again")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.red)
                    }
                    HStack(spacing: 16) {
                        Button("Hint") { viewModel.showHint() }
                            .buttonStyle(.bordered)
                        Button("Show Solution") { viewModel.showSolution() }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                        Button("Retry") { viewModel.retry() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding()

            case .solved:
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("Puzzle Solved!")
                            .font(.headline)
                            .foregroundStyle(.green)
                        if viewModel.streak > 1 {
                            Text("\(viewModel.streak) streak")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Button("Next Puzzle") {
                        viewModel.loadNextPuzzle()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

            case .failed:
                VStack(spacing: 8) {
                    Text("Solution shown")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        Button("Retry") { viewModel.retry() }
                            .buttonStyle(.bordered)
                        Button("Next Puzzle") { viewModel.loadNextPuzzle() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding()

            case .error(let message):
                VStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Failed to load puzzle")
                        .font(.headline)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        viewModel.loadNextPuzzle()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                }
                .padding()
            }
        }
    }

    // MARK: - Helpers

    private func ratingColor(_ rating: Int) -> Color {
        if rating < 1000 { return .green }
        if rating < 1500 { return .blue }
        if rating < 2000 { return .orange }
        return .red
    }

    private func formatTheme(_ theme: String) -> String {
        theme.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .capitalized
    }
}
