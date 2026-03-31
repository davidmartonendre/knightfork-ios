import SpriteKit
import ChessKit

/// The core SpriteKit scene that renders the chess board, pieces, and overlays.
/// All 64 squares are baked into a single texture for performance.
/// Pieces are individual SKSpriteNodes sharing a texture atlas.
final class ChessBoardScene: SKScene {

    // MARK: - Configuration

    var theme: BoardTheme = .classicGreen { didSet { rebuildBoard() } }
    var isFlipped: Bool = false

    // MARK: - Callbacks

    var onSquareTapped: ((Square) -> Void)?
    var onDragBegan: ((Square) -> Void)?
    var onDragMoved: ((CGPoint) -> Void)?
    var onDragEnded: ((Square?) -> Void)?
    var onPromotionSelected: ((Piece.Kind) -> Void)?

    // MARK: - Node Layers (ordered by zPosition)

    private let boardNode = SKSpriteNode()
    private let highlightLayer = SKNode()
    private let legalMoveLayer = SKNode()
    private let checkLayer = SKNode()
    private let pieceLayer = SKNode()
    private let draggedPieceNode = SKSpriteNode()
    private let arrowLayer = SKNode()
    private let coordinateLayer = SKNode()
    private let promotionLayer = SKNode()

    // MARK: - State

    private var layout: BoardLayoutCalculator!
    private var pieceNodes: [Square: SKSpriteNode] = [:]
    private var interactionState: BoardInteractionState = .idle
    private var cachedLegalMoves: [Square] = []
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private(set) var isReady = false

    /// Called when the scene has completed initial layout and is ready to display pieces.
    var onSceneReady: (() -> Void)?

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        anchorPoint = CGPoint(x: 0, y: 0)

        boardNode.zPosition = 0
        highlightLayer.zPosition = 1
        legalMoveLayer.zPosition = 2
        checkLayer.zPosition = 3
        pieceLayer.zPosition = 4
        draggedPieceNode.zPosition = 5
        arrowLayer.zPosition = 6
        coordinateLayer.zPosition = 7
        promotionLayer.zPosition = 8

        draggedPieceNode.isHidden = true

        addChild(boardNode)
        addChild(highlightLayer)
        addChild(legalMoveLayer)
        addChild(checkLayer)
        addChild(pieceLayer)
        addChild(draggedPieceNode)
        addChild(arrowLayer)
        addChild(coordinateLayer)
        addChild(promotionLayer)

        rebuildLayout()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0, size.height > 0 else { return }
        // Reset ready state so pieces get re-placed at the correct size
        let wasReady = isReady
        isReady = false
        rebuildLayout()
        // If we were already ready, notify again so coordinator re-applies
        if wasReady {
            onSceneReady?()
        }
    }

    // MARK: - Public API

    /// Update all pieces to match the given position.
    func updatePosition(_ position: Position, animated: Bool) {
        guard layout != nil else { return }
        let newPieces = position.pieces
        var newPiecesBySquare: [Square: Piece] = [:]
        for piece in newPieces {
            newPiecesBySquare[piece.square] = piece
        }

        // Remove pieces no longer present
        for (square, node) in pieceNodes {
            if newPiecesBySquare[square] == nil {
                if animated {
                    node.run(.sequence([.fadeOut(withDuration: 0.1), .removeFromParent()]))
                } else {
                    node.removeFromParent()
                }
                pieceNodes[square] = nil
            }
        }

        // Add or update pieces
        for piece in newPieces {
            let center = layout.centerOfSquare(piece.square, flipped: isFlipped)
            if let existingNode = pieceNodes[piece.square] {
                // Check if it's the same piece
                if existingNode.name == pieceNodeName(piece) {
                    if animated && existingNode.position != center {
                        existingNode.run(.move(to: center, duration: 0.08))
                    } else {
                        existingNode.position = center
                    }
                } else {
                    // Different piece on same square (e.g., promotion)
                    existingNode.removeFromParent()
                    let newNode = createPieceNode(piece)
                    newNode.position = center
                    pieceLayer.addChild(newNode)
                    pieceNodes[piece.square] = newNode
                }
            } else {
                // New piece
                let node = createPieceNode(piece)
                node.position = center
                if animated {
                    node.alpha = 0
                    node.run(.fadeIn(withDuration: 0.1))
                }
                pieceLayer.addChild(node)
                pieceNodes[piece.square] = node
            }
        }
    }

    /// Animate a piece from one square to another (e.g., after engine moves).
    func animateMove(from: Square, to: Square, duration: TimeInterval = 0.15, completion: (() -> Void)? = nil) {
        guard let node = pieceNodes[from] else {
            completion?()
            return
        }
        let dest = layout.centerOfSquare(to, flipped: isFlipped)
        pieceNodes[from] = nil
        // Remove any piece on the destination (captured)
        if let capturedNode = pieceNodes[to] {
            capturedNode.run(.sequence([.fadeOut(withDuration: duration * 0.5), .removeFromParent()]))
        }
        pieceNodes[to] = node
        let moveAction = SKAction.move(to: dest, duration: duration)
        moveAction.timingMode = .easeOut
        node.run(moveAction) {
            completion?()
        }
    }

    // MARK: - Overlays

    func showLastMoveHighlight(from: Square, to: Square) {
        highlightLayer.removeAllChildren()
        for sq in [from, to] {
            let origin = layout.originOfSquare(sq, flipped: isFlipped)
            let highlight = SKSpriteNode(color: theme.lastMoveHighlight, size: CGSize(width: layout.squareSize, height: layout.squareSize))
            highlight.anchorPoint = .zero
            highlight.position = origin
            highlightLayer.addChild(highlight)
        }
    }

    func clearLastMoveHighlight() {
        highlightLayer.removeAllChildren()
    }

    func showLegalMoves(_ squares: [Square], captures: [Square] = []) {
        legalMoveLayer.removeAllChildren()
        let dotRadius = layout.squareSize * 0.15
        let ringOuterRadius = layout.squareSize * 0.45
        let ringInnerRadius = layout.squareSize * 0.38

        for sq in squares {
            let center = layout.centerOfSquare(sq, flipped: isFlipped)
            if captures.contains(sq) {
                // Ring for captures
                let ring = SKShapeNode(circleOfRadius: ringOuterRadius)
                ring.strokeColor = theme.legalMoveDot
                ring.lineWidth = ringOuterRadius - ringInnerRadius
                ring.fillColor = .clear
                ring.position = center
                legalMoveLayer.addChild(ring)
            } else {
                // Dot for empty squares
                let dot = SKShapeNode(circleOfRadius: dotRadius)
                dot.fillColor = theme.legalMoveDot
                dot.strokeColor = .clear
                dot.position = center
                legalMoveLayer.addChild(dot)
            }
        }
    }

    func clearLegalMoves() {
        legalMoveLayer.removeAllChildren()
    }

    func showSelectedSquare(_ square: Square) {
        let tag = "selectedSquare"
        highlightLayer.childNode(withName: tag)?.removeFromParent()

        let origin = layout.originOfSquare(square, flipped: isFlipped)
        let node = SKSpriteNode(color: theme.selectedSquare, size: CGSize(width: layout.squareSize, height: layout.squareSize))
        node.anchorPoint = .zero
        node.position = origin
        node.name = tag
        highlightLayer.addChild(node)
    }

    func showCheck(on square: Square) {
        checkLayer.removeAllChildren()
        let center = layout.centerOfSquare(square, flipped: isFlipped)
        let size = layout.squareSize
        let check = SKShapeNode(circleOfRadius: size * 0.45)
        check.fillColor = theme.checkIndicator
        check.strokeColor = .clear
        check.position = center
        check.glowWidth = size * 0.1
        checkLayer.addChild(check)
    }

    func clearCheck() {
        checkLayer.removeAllChildren()
    }

    func showArrow(from: Square, to: Square, color: UIColor, lineWidth: CGFloat = 0) {
        let start = layout.centerOfSquare(from, flipped: isFlipped)
        let end = layout.centerOfSquare(to, flipped: isFlipped)
        let width = lineWidth > 0 ? lineWidth : layout.squareSize * 0.12

        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)

        let arrow = SKShapeNode(path: path)
        arrow.strokeColor = color
        arrow.lineWidth = width
        arrow.lineCap = .round
        arrowLayer.addChild(arrow)

        // Arrowhead
        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength = layout.squareSize * 0.25
        let headPath = CGMutablePath()
        headPath.move(to: end)
        headPath.addLine(to: CGPoint(
            x: end.x - headLength * cos(angle - .pi / 6),
            y: end.y - headLength * sin(angle - .pi / 6)
        ))
        headPath.addLine(to: CGPoint(
            x: end.x - headLength * cos(angle + .pi / 6),
            y: end.y - headLength * sin(angle + .pi / 6)
        ))
        headPath.closeSubpath()

        let head = SKShapeNode(path: headPath)
        head.fillColor = color
        head.strokeColor = .clear
        arrowLayer.addChild(head)
    }

    func clearArrows() {
        arrowLayer.removeAllChildren()
    }

    func showCoordinates() {
        coordinateLayer.removeAllChildren()
        let fontSize = layout.squareSize * 0.18
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)

        // File letters on bottom rank
        let files: [Square.File] = [.a, .b, .c, .d, .e, .f, .g, .h]
        for file in files {
            let notation = "\(file)"
            let square = isFlipped
                ? squareFromFileRank(file: file, rank: 8)
                : squareFromFileRank(file: file, rank: 1)
            guard let sq = square else { continue }
            let origin = layout.originOfSquare(sq, flipped: isFlipped)
            let label = SKLabelNode(text: notation)
            label.fontName = font.fontName
            label.fontSize = fontSize
            label.fontColor = theme.coordinateFont
            label.horizontalAlignmentMode = .right
            label.verticalAlignmentMode = .bottom
            label.position = CGPoint(
                x: origin.x + layout.squareSize - 2,
                y: origin.y + 2
            )
            coordinateLayer.addChild(label)
        }

        // Rank numbers on left file
        for rank in 1...8 {
            let file: Square.File = isFlipped ? .h : .a
            guard let sq = squareFromFileRank(file: file, rank: rank) else { continue }
            let origin = layout.originOfSquare(sq, flipped: isFlipped)
            let label = SKLabelNode(text: "\(rank)")
            label.fontName = font.fontName
            label.fontSize = fontSize
            label.fontColor = theme.coordinateFont
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.position = CGPoint(
                x: origin.x + 2,
                y: origin.y + layout.squareSize - 2
            )
            coordinateLayer.addChild(label)
        }
    }

    func showPromotionPicker(at square: Square, color: Piece.Color) {
        promotionLayer.removeAllChildren()

        let kinds: [Piece.Kind] = [.queen, .rook, .bishop, .knight]
        let itemSize = layout.squareSize * 0.9
        let totalWidth = CGFloat(kinds.count) * itemSize + CGFloat(kinds.count - 1) * 4
        let center = layout.centerOfSquare(square, flipped: isFlipped)
        let startX = center.x - totalWidth / 2 + itemSize / 2

        // Background
        let bg = SKShapeNode(rectOf: CGSize(width: totalWidth + 16, height: itemSize + 16), cornerRadius: 8)
        bg.fillColor = UIColor.systemBackground.withAlphaComponent(0.95)
        bg.strokeColor = UIColor.separator
        bg.lineWidth = 1
        bg.position = center
        promotionLayer.addChild(bg)

        for (i, kind) in kinds.enumerated() {
            let tex = PieceImageProvider.shared.texture(for: kind, color: color, squareSize: layout.squareSize)
            let sprite = SKSpriteNode(texture: tex, size: CGSize(width: itemSize, height: itemSize))
            sprite.position = CGPoint(x: startX + CGFloat(i) * (itemSize + 4), y: center.y)
            sprite.name = "promo_\(kind)"
            promotionLayer.addChild(sprite)
        }
    }

    func hidePromotionPicker() {
        promotionLayer.removeAllChildren()
    }

    /// Flip all piece positions with animation and refresh all overlays.
    func flipBoard(animated: Bool) {
        guard layout != nil else { return }
        if animated {
            for (square, node) in pieceNodes {
                let newCenter = layout.centerOfSquare(square, flipped: isFlipped)
                let action = SKAction.move(to: newCenter, duration: 0.3)
                action.timingMode = .easeInEaseOut
                node.run(action)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.refreshAllOverlays()
            }
        } else {
            for (square, node) in pieceNodes {
                node.position = layout.centerOfSquare(square, flipped: isFlipped)
            }
            refreshAllOverlays()
        }
    }

    /// Callback for the coordinator to re-apply overlays after flip.
    var onFlipCompleted: (() -> Void)?

    private func refreshAllOverlays() {
        showCoordinates()
        // Ask the coordinator to re-apply highlights, check, arrows
        onFlipCompleted?()
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, layout != nil else { return }
        let point = touch.location(in: self)

        // Check promotion picker first
        if !promotionLayer.children.isEmpty {
            let promoNodes = promotionLayer.nodes(at: point)
            for node in promoNodes {
                if let name = node.name, name.hasPrefix("promo_") {
                    let kindStr = String(name.dropFirst(6))
                    if let kind = promotionKind(from: kindStr) {
                        onPromotionSelected?(kind)
                        hidePromotionPicker()
                        return
                    }
                }
            }
            // Tapped outside promotion picker — cancel
            hidePromotionPicker()
            interactionState = .idle
            clearLegalMoves()
            return
        }

        guard let square = layout.square(at: point, flipped: isFlipped) else { return }

        haptic.prepare()

        switch interactionState {
        case .idle:
            // Try to start drag or select
            if let pieceNode = pieceNodes[square] {
                startDragging(square: square, pieceNode: pieceNode, at: point)
            }

        case .selected(let selectedSquare):
            if square == selectedSquare {
                // Deselect
                interactionState = .idle
                clearLegalMoves()
                highlightLayer.childNode(withName: "selectedSquare")?.removeFromParent()
            } else if cachedLegalMoves.contains(square) {
                // Complete tap-tap move
                onSquareTapped?(square)
                interactionState = .idle
                clearLegalMoves()
                highlightLayer.childNode(withName: "selectedSquare")?.removeFromParent()
            } else if pieceNodes[square] != nil {
                // Select different piece
                clearLegalMoves()
                highlightLayer.childNode(withName: "selectedSquare")?.removeFromParent()
                startDragging(square: square, pieceNode: pieceNodes[square]!, at: point)
            } else {
                // Deselect
                interactionState = .idle
                clearLegalMoves()
                highlightLayer.childNode(withName: "selectedSquare")?.removeFromParent()
            }

        default:
            break
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, layout != nil else { return }
        guard case .dragging = interactionState else { return }
        let point = layout.clampToBoard(touch.location(in: self))
        draggedPieceNode.position = point
        onDragMoved?(point)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, layout != nil else { return }
        let point = touch.location(in: self)

        guard case .dragging(let fromSquare, let originalNode) = interactionState else { return }

        let dropSquare = layout.square(at: point, flipped: isFlipped)

        // Check if piece was barely moved (treat as tap-to-select)
        let dragDistance = hypot(
            draggedPieceNode.position.x - layout.centerOfSquare(fromSquare, flipped: isFlipped).x,
            draggedPieceNode.position.y - layout.centerOfSquare(fromSquare, flipped: isFlipped).y
        )

        draggedPieceNode.isHidden = true

        if dragDistance < layout.squareSize * 0.3 {
            // Treat as tap: select the piece
            originalNode.setScale(1.0)
            originalNode.alpha = 1.0
            interactionState = .selected(fromSquare)
            showSelectedSquare(fromSquare)
            onDragBegan?(fromSquare)  // Triggers legal move display
            return
        }

        if let target = dropSquare, cachedLegalMoves.contains(target) {
            // Legal drop — animate snap
            originalNode.alpha = 1.0
            originalNode.setScale(1.0)
            let dest = layout.centerOfSquare(target, flipped: isFlipped)
            let snap = SKAction.move(to: dest, duration: 0.08)
            snap.timingMode = .easeOut
            originalNode.run(snap)
            haptic.impactOccurred()
            clearLegalMoves()
            interactionState = .idle
            onDragEnded?(target)
        } else {
            // Illegal drop — snap back
            let origin = layout.centerOfSquare(fromSquare, flipped: isFlipped)
            let returnAction = SKAction.move(to: origin, duration: 0.12)
            returnAction.timingMode = .easeOut
            originalNode.alpha = 1.0
            originalNode.run(SKAction.group([returnAction, .scale(to: 1.0, duration: 0.08)]))
            clearLegalMoves()
            interactionState = .idle
            onDragEnded?(nil)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard case .dragging(let fromSquare, let originalNode) = interactionState else { return }
        draggedPieceNode.isHidden = true
        originalNode.alpha = 1.0
        originalNode.setScale(1.0)
        if layout != nil {
            originalNode.position = layout.centerOfSquare(fromSquare, flipped: isFlipped)
        }
        clearLegalMoves()
        interactionState = .idle
    }

    // MARK: - Private: Drag Helpers

    private func startDragging(square: Square, pieceNode: SKSpriteNode, at point: CGPoint) {
        cachedLegalMoves = []
        onDragBegan?(square)
        interactionState = .dragging(from: square, pieceNode: pieceNode)

        // Lift effect on original
        pieceNode.alpha = 0.3

        // Show dragged piece
        draggedPieceNode.texture = pieceNode.texture
        draggedPieceNode.size = pieceNode.size
        draggedPieceNode.setScale(1.15)
        draggedPieceNode.position = point
        draggedPieceNode.isHidden = false
    }

    // MARK: - Private: Board Rendering

    private func rebuildLayout() {
        guard size.width > 0, size.height > 0 else { return }
        layout = BoardLayoutCalculator(sceneWidth: size.width, sceneHeight: size.height)
        rebuildBoard()
        if !isReady {
            isReady = true
            onSceneReady?()
        }
    }

    private func rebuildBoard() {
        guard layout != nil else { return }
        renderBoardTexture()
        showCoordinates()

        // Remove all existing pieces — they'll be re-created by updatePosition
        // at the correct size for the new layout
        for (_, node) in pieceNodes {
            node.removeFromParent()
        }
        pieceNodes.removeAll()
        PieceImageProvider.shared.clearCache()
    }

    private func renderBoardTexture() {
        let size = CGSize(width: layout.boardSize, height: layout.boardSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let context = ctx.cgContext
            let sq = layout.squareSize
            for rank in 1...8 {
                for fileNum in 1...8 {
                    let isLight = (rank + fileNum) % 2 == 0
                    let color = isLight ? theme.lightSquare : theme.darkSquare
                    context.setFillColor(color.cgColor)
                    // UIKit coords (y=0 top). SpriteKit flips the image vertically.
                    // rank 1 → row 0 (top of UIKit) → bottom of SpriteKit scene
                    let col = fileNum - 1
                    let row = rank - 1
                    context.fill(CGRect(x: CGFloat(col) * sq, y: CGFloat(row) * sq, width: sq, height: sq))
                }
            }
        }

        boardNode.texture = SKTexture(image: image)
        boardNode.size = size
        boardNode.anchorPoint = .zero
        boardNode.position = layout.boardOrigin
    }

    private func createPieceNode(_ piece: Piece) -> SKSpriteNode {
        let tex = PieceImageProvider.shared.texture(for: piece.kind, color: piece.color, squareSize: layout.squareSize)
        let node = SKSpriteNode(texture: tex, size: CGSize(width: layout.squareSize * 0.85, height: layout.squareSize * 0.85))
        node.name = pieceNodeName(piece)
        return node
    }

    private func pieceNodeName(_ piece: Piece) -> String {
        "\(piece.color)-\(piece.kind)-\(piece.square.notation)"
    }

    /// Called externally to set cached legal moves (from the ViewModel).
    func setCachedLegalMoves(_ moves: [Square]) {
        self.cachedLegalMoves = moves
    }

    // MARK: - Helpers

    private func promotionKind(from string: String) -> Piece.Kind? {
        switch string {
        case "queen":  return .queen
        case "rook":   return .rook
        case "bishop": return .bishop
        case "knight": return .knight
        default: return nil
        }
    }

    private func squareFromFileRank(file: Square.File, rank: Int) -> Square? {
        guard (1...8).contains(rank) else { return nil }
        return Square("\(file)\(rank)")
    }
}
