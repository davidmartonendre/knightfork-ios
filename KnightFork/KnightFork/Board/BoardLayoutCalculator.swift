import CoreGraphics
import UIKit
import ChessKit

/// Pure geometry calculations for the chess board.
/// Converts between screen coordinates and chess squares.
struct BoardLayoutCalculator {
    let squareSize: CGFloat
    let boardSize: CGFloat
    let boardOrigin: CGPoint

    init(sceneWidth: CGFloat, sceneHeight: CGFloat) {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let maxBoardSize: CGFloat = isIPad ? 560 : sceneWidth
        let size = min(maxBoardSize, sceneWidth, sceneHeight)
        self.boardSize = size
        self.squareSize = size / 8
        self.boardOrigin = CGPoint(
            x: (sceneWidth - size) / 2,
            y: (sceneHeight - size) / 2
        )
    }

    /// Returns the center point of a square in scene coordinates.
    func centerOfSquare(_ square: Square, flipped: Bool) -> CGPoint {
        let col = fileIndex(square.file, flipped: flipped)
        let row = rankIndex(square.rank, flipped: flipped)
        return CGPoint(
            x: boardOrigin.x + (CGFloat(col) + 0.5) * squareSize,
            y: boardOrigin.y + (CGFloat(row) + 0.5) * squareSize
        )
    }

    /// Returns the origin (bottom-left) of a square in scene coordinates.
    func originOfSquare(_ square: Square, flipped: Bool) -> CGPoint {
        let col = fileIndex(square.file, flipped: flipped)
        let row = rankIndex(square.rank, flipped: flipped)
        return CGPoint(
            x: boardOrigin.x + CGFloat(col) * squareSize,
            y: boardOrigin.y + CGFloat(row) * squareSize
        )
    }

    /// Returns the square at a given scene point, or nil if outside the board.
    func square(at point: CGPoint, flipped: Bool) -> Square? {
        let localX = point.x - boardOrigin.x
        let localY = point.y - boardOrigin.y

        guard localX >= 0, localX < boardSize, localY >= 0, localY < boardSize else {
            return nil
        }

        let col = Int(localX / squareSize)
        let row = Int(localY / squareSize)

        // SpriteKit: row 0 is bottom. Unflipped: row 0 = rank 1.
        let fileNum = flipped ? (8 - col) : (col + 1)
        let rankVal = flipped ? (8 - row) : (row + 1)

        guard let file = squareFile(number: fileNum) else { return nil }
        return squareFromFileRank(file: file, rank: rankVal)
    }

    /// Clamps a point to within the board bounds.
    func clampToBoard(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: max(boardOrigin.x, min(point.x, boardOrigin.x + boardSize)),
            y: max(boardOrigin.y, min(point.y, boardOrigin.y + boardSize))
        )
    }

    // MARK: - Private Helpers

    private func fileIndex(_ file: Square.File, flipped: Bool) -> Int {
        let idx = file.number - 1  // 0-7
        return flipped ? (7 - idx) : idx
    }

    private func rankIndex(_ rank: Square.Rank, flipped: Bool) -> Int {
        // SpriteKit: y=0 is bottom of scene.
        // Unflipped: rank 1 at bottom (row 0), rank 8 at top (row 7)
        // Flipped: rank 8 at bottom (row 0), rank 1 at top (row 7)
        let idx = rank.value - 1  // 0-7
        return flipped ? (7 - idx) : idx
    }

    private func squareFile(number: Int) -> Square.File? {
        switch number {
        case 1: return .a
        case 2: return .b
        case 3: return .c
        case 4: return .d
        case 5: return .e
        case 6: return .f
        case 7: return .g
        case 8: return .h
        default: return nil
        }
    }

    private func squareFromFileRank(file: Square.File, rank: Int) -> Square? {
        guard (1...8).contains(rank) else { return nil }
        let notation = "\(file)\(rank)"
        return Square(notation)
    }
}
