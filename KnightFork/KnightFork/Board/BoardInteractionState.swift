import ChessKit
import SpriteKit

/// Tracks the current interaction state of the board.
enum BoardInteractionState {
    case idle
    case selected(Square)
    case dragging(from: Square, pieceNode: SKSpriteNode)
    case promotionPending(from: Square, to: Square)
}

/// Controls what the user can do on the board.
enum BoardInteractionMode {
    case play(as: Piece.Color)   // Only move pieces of this color
    case analysis                 // Move any piece (both sides)
    case viewOnly                 // No interaction, just viewing
}
