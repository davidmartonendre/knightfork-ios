import Foundation
import Observation
import ChessKit
import OSLog

private let log = Logger(subsystem: "com.knightfork", category: "Puzzle")

enum PuzzleState: Equatable {
    case loading
    case ready           // Setup move played, waiting for player
    case correct         // Player got the current move right, auto-playing response
    case wrong           // Player got it wrong
    case solved          // All solution moves found
    case failed          // Gave up or wrong and chose to skip
    case error(String)   // Network/parse error
}

@Observable
final class PuzzleViewModel {
    // MARK: - Public State
    var state: PuzzleState = .loading
    var boardViewModel = BoardViewModel()
    var currentPuzzle: Puzzle?
    var hintSquare: Square?

    // Stats for the session
    var solved = 0
    var failed = 0
    var attempted = 0
    var streak = 0

    // Filters
    var difficulty: PuzzleDifficulty = .normal
    var theme: PuzzleThemeOption = .mix

    // MARK: - Private
    private var currentSolutionStep = 0
    private let db = PuzzleDatabase.shared

    // MARK: - Lifecycle

    func loadNextPuzzle() {
        state = .loading
        hintSquare = nil
        currentSolutionStep = 0

        Task { @MainActor in
            do {
                let puzzle = try await db.nextPuzzle(theme: theme, difficulty: difficulty)
                self.currentPuzzle = puzzle
                self.attempted += 1
                log.info("Puzzle \(puzzle.id): rating=\(puzzle.rating) solution=\(puzzle.solutionMoves.joined(separator: " "))")
                self.setupPuzzlePosition(puzzle)
            } catch {
                log.error("Failed to load puzzle: \(error.localizedDescription)")
                self.state = .error(error.localizedDescription)
            }
        }
    }

    /// Called when the player makes a move on the board.
    func playerMoved(from: Square, to: Square) {
        guard state == .ready, let puzzle = currentPuzzle else { return }

        let solution = puzzle.solutionMoves
        guard currentSolutionStep < solution.count else { return }

        let expectedUCI = solution[currentSolutionStep]
        let playerUCI = "\(from.notation)\(to.notation)"

        // Match first 4 chars (ignore promotion suffix for now)
        let matches = playerUCI == String(expectedUCI.prefix(4))

        if matches {
            let step = currentSolutionStep
            log.info("Correct move \(step + 1)/\(solution.count): \(playerUCI)")
            currentSolutionStep += 1

            if currentSolutionStep >= solution.count {
                state = .solved
                solved += 1
                streak += 1
                log.info("Puzzle solved! Streak: \(self.streak)")
                return
            }

            // Auto-play opponent's response
            state = .correct
            hintSquare = nil
            Task { @MainActor [self] in
                try? await Task.sleep(for: .milliseconds(400))
                self.playOpponentResponse()
            }
        } else {
            log.info("Wrong: played \(playerUCI), expected \(expectedUCI)")
            state = .wrong
            streak = 0
            boardViewModel.goBack()
        }
    }

    /// Show a hint (highlight the origin square of the next move).
    func showHint() {
        guard let puzzle = currentPuzzle,
              currentSolutionStep < puzzle.solutionMoves.count else { return }

        let nextMove = puzzle.solutionMoves[currentSolutionStep]
        guard nextMove.count >= 2 else { return }
        hintSquare = Square(String(nextMove.prefix(2)))
    }

    /// Show the full solution — mark as failed.
    func showSolution() {
        guard let puzzle = currentPuzzle else { return }
        state = .failed
        failed += 1
        streak = 0

        let remaining = Array(puzzle.solutionMoves.dropFirst(currentSolutionStep))
        Task { @MainActor in
            for uci in remaining {
                try? await Task.sleep(for: .milliseconds(300))
                self.playUCIMove(uci)
            }
        }
    }

    /// Retry the current puzzle from the beginning.
    func retry() {
        guard let puzzle = currentPuzzle else { return }
        currentSolutionStep = 0
        hintSquare = nil
        setupPuzzlePosition(puzzle)
    }

    /// Clear cache when filters change.
    func filtersChanged() {
        db.clearCache()
    }

    // MARK: - Private

    private func setupPuzzlePosition(_ puzzle: Puzzle) {
        guard let position = Position(fen: puzzle.fen) else {
            log.error("Invalid FEN: \(puzzle.fen)")
            state = .error("Invalid puzzle position")
            return
        }

        let game = Game(startingWith: position)
        boardViewModel.loadGame(game)

        // Player color = opposite of side to move in the FEN
        let playerColor: Piece.Color = position.sideToMove == .white ? .black : .white
        boardViewModel.interactionMode = .play(as: playerColor)
        boardViewModel.isFlipped = playerColor == .black

        log.info("Setup: FEN=\(puzzle.fen)")
        log.info("Setup: sideToMove=\(position.sideToMove == .white ? "w" : "b"), playerColor=\(playerColor == .white ? "w" : "b")")
        log.info("Setup: setupMove=\(puzzle.setupMove ?? "none"), solution=\(puzzle.solutionMoves.joined(separator: " "))")
        log.info("Setup: interactionMode=play(as: \(playerColor == .white ? "white" : "black"))")

        // Play the setup move after a short delay
        guard let setupUCI = puzzle.setupMove, setupUCI.count >= 4 else {
            state = .ready
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            self.playUCIMove(setupUCI)
            log.info("After setup move: boardFEN=\(self.boardViewModel.currentPosition.fen), side=\(self.boardViewModel.sideToMove == .white ? "w" : "b")")
            self.state = .ready
        }
    }

    private func playOpponentResponse() {
        guard let puzzle = currentPuzzle else { return }
        let solution = puzzle.solutionMoves

        guard currentSolutionStep < solution.count else {
            state = .solved
            solved += 1
            streak += 1
            return
        }

        playUCIMove(solution[currentSolutionStep])
        currentSolutionStep += 1

        if currentSolutionStep >= solution.count {
            state = .solved
            solved += 1
            streak += 1
            log.info("Puzzle solved! Streak: \(self.streak)")
        } else {
            state = .ready
        }
    }

    private func playUCIMove(_ uci: String) {
        guard uci.count >= 4 else {
            log.error("UCI move too short: \(uci)")
            return
        }
        let from = Square(String(uci.prefix(2)))
        let to = Square(String(uci.dropFirst(2).prefix(2)))

        let sideStr = boardViewModel.sideToMove == .white ? "w" : "b"
        let pieceDesc = boardViewModel.currentPosition.piece(at: from).map { "\($0.kind)" } ?? "nil"
        log.info("Playing UCI \(uci): \(from.notation)→\(to.notation), side=\(sideStr), piece=\(pieceDesc)")

        if let move = boardViewModel.makeMove(from: from, to: to) {
            log.info("Move applied: \(move.san), now side=\(self.boardViewModel.sideToMove == .white ? "w" : "b")")
            if uci.count == 5, boardViewModel.isPromotionPending {
                let kind: Piece.Kind
                switch uci.last {
                case "q": kind = .queen
                case "r": kind = .rook
                case "b": kind = .bishop
                case "n": kind = .knight
                default: kind = .queen
                }
                boardViewModel.completePromotion(to: kind)
            }
        } else {
            log.error("makeMove FAILED for \(uci). Board FEN: \(self.boardViewModel.currentPosition.fen)")
        }
    }
}
