import SwiftUI
import SpriteKit
import ChessKit

/// SwiftUI wrapper that embeds the SpriteKit chess board scene.
struct ChessBoardView: UIViewRepresentable {
    let viewModel: BoardViewModel

    func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 120
        skView.allowsTransparency = true
        skView.backgroundColor = .clear

        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true
        #endif

        let scene = ChessBoardScene()
        scene.scaleMode = .resizeFill
        scene.theme = viewModel.theme
        scene.isFlipped = viewModel.isFlipped

        // Set up callbacks BEFORE presenting so onSceneReady isn't missed
        context.coordinator.scene = scene
        context.coordinator.setupCallbacks()

        skView.presentScene(scene)

        // Add swipe gestures for navigation
        let swipeLeft = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipeLeft))
        swipeLeft.direction = .left
        skView.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipeRight))
        swipeRight.direction = .right
        skView.addGestureRecognizer(swipeRight)

        return skView
    }

    func updateUIView(_ skView: SKView, context: Context) {
        let coordinator = context.coordinator
        coordinator.applyState(viewModel)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: SKView, context: Context) -> CGSize? {
        let width = proposal.width ?? 390
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let maxSize: CGFloat = isIPad ? 560 : width
        let size = min(maxSize, width)
        return CGSize(width: size, height: size)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        let viewModel: BoardViewModel
        var scene: ChessBoardScene?

        // Track last-applied state to avoid redundant updates
        private var lastPositionFEN: String = ""
        private var lastMoveFrom: String = ""
        private var lastMoveTo: String = ""
        private var lastIsFlipped: Bool = false
        private var lastThemeId: String = ""
        private var lastCheckSquare: String = ""

        // Track drag source for move completion
        private var lastDragSource: Square?
        private var selectedSquare: Square?
        private var hasLoadedPieces = false

        init(viewModel: BoardViewModel) {
            self.viewModel = viewModel
        }

        func setupCallbacks() {
            guard let scene else { return }

            scene.onSceneReady = { [weak self] in
                guard let self else { return }
                // Reset caches so everything gets redrawn at the correct size
                self.lastPositionFEN = ""
                self.lastThemeId = ""
                self.hasLoadedPieces = false
                self.applyState(self.viewModel)
            }

            scene.onFlipCompleted = { [weak self] in
                guard let self, let scene = self.scene else { return }
                // Re-apply all overlays at new positions
                let vm = self.viewModel
                if let lm = vm.lastMove {
                    scene.showLastMoveHighlight(from: lm.from, to: lm.to)
                }
                if let sq = vm.checkSquare {
                    scene.showCheck(on: sq)
                } else {
                    scene.clearCheck()
                }
                scene.clearArrows()
                for arrow in vm.analysisArrows {
                    scene.showArrow(from: arrow.from, to: arrow.to, color: arrow.color)
                }
            }

            scene.onDragBegan = { [weak self] square in
                guard let self else { return }
                self.lastDragSource = square
                self.selectedSquare = square
                let legal = self.viewModel.legalMoves(from: square)
                scene.setCachedLegalMoves(legal)

                // Determine which are captures
                let captures = legal.filter { sq in
                    self.viewModel.currentPosition.piece(at: sq) != nil
                }
                scene.showLegalMoves(legal, captures: captures)
            }

            scene.onDragEnded = { [weak self] targetSquare in
                guard let self, let target = targetSquare else { return }
                if let from = self.lastDragSource {
                    self.attemptMove(from: from, to: target)
                    self.lastDragSource = nil
                }
            }

            scene.onSquareTapped = { [weak self] square in
                guard let self, let from = self.selectedSquare else { return }
                self.attemptMove(from: from, to: square)
                self.selectedSquare = nil
            }

            scene.onPromotionSelected = { [weak self] kind in
                self?.viewModel.completePromotion(to: kind)
                self?.refreshBoard(animated: true)
            }
        }

        func applyState(_ vm: BoardViewModel) {
            guard let scene, scene.isReady else { return }

            let currentFEN = vm.currentPosition.fen

            // Theme change
            if vm.theme.id != lastThemeId {
                scene.theme = vm.theme
                lastThemeId = vm.theme.id
            }

            // Flip change
            if vm.isFlipped != lastIsFlipped {
                scene.isFlipped = vm.isFlipped
                scene.flipBoard(animated: true)
                lastIsFlipped = vm.isFlipped
            }

            // Position change — also force update if pieces were never loaded
            if currentFEN != lastPositionFEN || !hasLoadedPieces {
                scene.updatePosition(vm.currentPosition, animated: !hasLoadedPieces ? false : true)
                lastPositionFEN = currentFEN
                hasLoadedPieces = true

                // Update last move highlight
                if let lm = vm.lastMove {
                    scene.showLastMoveHighlight(from: lm.from, to: lm.to)
                    lastMoveFrom = lm.from.notation
                    lastMoveTo = lm.to.notation
                } else {
                    scene.clearLastMoveHighlight()
                    lastMoveFrom = ""
                    lastMoveTo = ""
                }

                // Update check indicator
                let checkNotation = vm.checkSquare?.notation ?? ""
                if checkNotation != lastCheckSquare {
                    if let sq = vm.checkSquare {
                        scene.showCheck(on: sq)
                    } else {
                        scene.clearCheck()
                    }
                    lastCheckSquare = checkNotation
                }
            }

            // Update analysis arrows
            scene.clearArrows()
            for arrow in vm.analysisArrows {
                scene.showArrow(from: arrow.from, to: arrow.to, color: arrow.color)
            }
        }

        // MARK: - Move Handling

        private func attemptMove(from: Square, to: Square) {
            let move = viewModel.makeMove(from: from, to: to)
            if move != nil {
                if viewModel.isPromotionPending {
                    scene?.showPromotionPicker(at: to, color: viewModel.sideToMove == .white ? .black : .white)
                } else {
                    refreshBoard(animated: true)
                }
            }
        }

        private func refreshBoard(animated: Bool) {
            guard let scene else { return }
            scene.updatePosition(viewModel.currentPosition, animated: animated)
            lastPositionFEN = viewModel.currentPosition.fen

            if let lm = viewModel.lastMove {
                scene.showLastMoveHighlight(from: lm.from, to: lm.to)
            } else {
                scene.clearLastMoveHighlight()
            }

            if let sq = viewModel.checkSquare {
                scene.showCheck(on: sq)
            } else {
                scene.clearCheck()
            }
        }

        // MARK: - Swipe Gestures

        @objc func handleSwipeLeft() {
            viewModel.goForward()
        }

        @objc func handleSwipeRight() {
            viewModel.goBack()
        }
    }
}
