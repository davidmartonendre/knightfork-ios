import Foundation
import Observation
import ChessKit
import UIKit

/// Central state manager for the chess board.
/// Holds the game, validates moves, and manages navigation.
@Observable
final class BoardViewModel {

    // MARK: - Published State

    private(set) var game: Game
    private(set) var board: Board
    private(set) var currentIndex: MoveTree.Index
    private(set) var lastMove: (from: Square, to: Square)?
    private(set) var checkSquare: Square?

    var isFlipped: Bool = false
    var theme: BoardTheme = .classicGreen
    var interactionMode: BoardInteractionMode = .analysis
    var analysisArrows: [(from: Square, to: Square, color: UIColor)] = []

    // MARK: - Computed

    var currentPosition: Position {
        game.positions[currentIndex] ?? .standard
    }

    var pieces: [Piece] {
        currentPosition.pieces
    }

    var sideToMove: Piece.Color {
        currentPosition.sideToMove
    }

    var canGoBack: Bool {
        currentIndex != game.startingIndex
    }

    var canGoForward: Bool {
        let nextIdx = currentIndex.next
        return game.moves[nextIdx] != nil
    }

    var boardState: Board.State {
        board.state
    }

    // MARK: - Init

    init(game: Game = Game()) {
        self.game = game
        self.board = Board(position: game.startingPosition ?? .standard)
        self.currentIndex = game.startingIndex
    }

    // MARK: - Move Validation

    /// Returns legal destination squares for a piece at the given square.
    func legalMoves(from square: Square) -> [Square] {
        guard canInteract(with: square) else { return [] }
        return board.legalMoves(forPieceAt: square)
    }

    /// Whether the user is allowed to interact with a piece on this square.
    func canInteract(with square: Square) -> Bool {
        guard let piece = currentPosition.piece(at: square) else { return false }
        switch interactionMode {
        case .play(let color):
            return piece.color == color && sideToMove == color
        case .analysis:
            return piece.color == sideToMove
        case .viewOnly:
            return false
        }
    }

    // MARK: - Making Moves

    /// Attempts to make a move. Returns the Move if successful, nil if illegal.
    @discardableResult
    func makeMove(from start: Square, to end: Square) -> Move? {
        guard let move = board.move(pieceAt: start, to: end) else {
            return nil
        }

        // Check if promotion is needed
        if case .promotion = board.state {
            // Caller should handle promotion separately
            return move
        }

        // Add to game tree
        currentIndex = game.make(move: move, from: currentIndex)
        lastMove = (from: start, to: end)
        updateCheckState()
        return move
    }

    /// Complete a pawn promotion.
    func completePromotion(to kind: Piece.Kind) {
        guard case .promotion(let move) = board.state else { return }
        let completed = board.completePromotion(of: move, to: kind)
        currentIndex = game.make(move: completed, from: currentIndex)
        lastMove = (from: completed.start, to: completed.end)
        updateCheckState()
    }

    /// Whether the board is currently awaiting a promotion choice.
    var isPromotionPending: Bool {
        if case .promotion = board.state { return true }
        return false
    }

    // MARK: - Navigation

    func goToStart() {
        navigateTo(index: game.startingIndex)
    }

    func goBack() {
        guard canGoBack else { return }
        navigateTo(index: currentIndex.previous)
    }

    func goForward() {
        guard canGoForward else { return }
        navigateTo(index: currentIndex.next)
    }

    func goToEnd() {
        let future = game.moves.future(for: currentIndex)
        guard let lastIndex = future.last else { return }
        navigateTo(index: lastIndex)
    }

    // MARK: - Game Management

    func loadGame(_ newGame: Game) {
        self.game = newGame
        self.currentIndex = newGame.startingIndex
        let startPos = newGame.startingPosition ?? .standard
        self.board = Board(position: startPos)
        self.lastMove = nil
        self.checkSquare = nil

        // Replay moves to get to starting position's board state
        replayToCurrentIndex()
    }

    func newGame() {
        loadGame(Game())
    }

    // MARK: - Private

    private func navigateTo(index: MoveTree.Index) {
        currentIndex = index

        // Use the cached position from the Game object directly.
        // This avoids replaying moves which can desync castling/en passant state.
        if let position = game.positions[index] {
            board.update(position: position)
        } else {
            // Fallback: replay from start
            replayToCurrentIndex()
        }

        // Update last move highlight
        if let move = game.moves[index] {
            lastMove = (from: move.start, to: move.end)
        } else {
            lastMove = nil
        }

        updateCheckState()
    }

    private func replayToCurrentIndex() {
        let history = game.moves.history(for: currentIndex)
        let startPos = game.startingPosition ?? .standard
        board = Board(position: startPos)

        for idx in history {
            if let move = game.moves[idx] {
                _ = board.move(pieceAt: move.start, to: move.end)
                if case .promotion(let promMove) = board.state,
                   let promoted = move.promotedPiece {
                    _ = board.completePromotion(of: promMove, to: promoted.kind)
                }
            }
        }
    }

    private func updateCheckState() {
        switch board.state {
        case .check(let color):
            checkSquare = findKing(color: color)
        case .checkmate(let color):
            checkSquare = findKing(color: color)
        default:
            checkSquare = nil
        }
    }

    private func findKing(color: Piece.Color) -> Square? {
        currentPosition.pieces.first(where: { $0.kind == .king && $0.color == color })?.square
    }
}
