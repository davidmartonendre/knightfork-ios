import SwiftUI
import SwiftData
import ChessKit
import ChessKitEngine

/// Full game screen for playing against the engine.
struct PlayGameView: View {
    let config: GameConfig
    @State private var viewModel = BoardViewModel()
    @State private var engineRegistry = EngineRegistry.shared
    @Environment(\.modelContext) private var modelContext
    @State private var playerColor: Piece.Color = .white
    @State private var isEngineThinking = false
    @State private var gameOver = false
    @State private var moveList: [String] = []
    @State private var showResignConfirm = false
    @State private var playerJustMoved = false  // True only when player makes a new move
    @State private var isNavigating = false       // True during view-only navigation
    @State private var liveIndex: MoveTree.Index? // The "live" position (latest move)

    // Clock state
    @State private var whiteTimeMs: Int = 0
    @State private var blackTimeMs: Int = 0
    @State private var incrementMs: Int = 0
    @State private var isTimed = false
    @State private var isClockRunning = false
    @State private var clockTimer: Timer?

    private var captured: (whiteCaptured: String, blackCaptured: String, materialDiff: Int) {
        CapturedPiecesCalculator.compute(from: viewModel.pieces)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Opponent info bar (engine)
            let isEngineWhite = playerColor == .black
            PlayerInfoBar(
                name: engineRegistry.activeDescriptor?.displayName ?? "Stockfish 17",
                elo: config.engineElo,
                timeMs: isTimed ? (isEngineWhite ? whiteTimeMs : blackTimeMs) : nil,
                isActive: viewModel.sideToMove != playerColor && isClockRunning,
                isThinking: isEngineThinking,
                capturedPieces: isEngineWhite ? captured.whiteCaptured : captured.blackCaptured,
                materialDiff: isEngineWhite ? max(0, captured.materialDiff) : max(0, -captured.materialDiff)
            )

            // Board
            ChessBoardView(viewModel: viewModel)
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 4)
                .allowsHitTesting(!isEngineThinking && !gameOver && !isViewingHistory)

            // Player info bar
            PlayerInfoBar(
                name: "You",
                elo: nil,
                timeMs: isTimed ? (playerColor == .white ? whiteTimeMs : blackTimeMs) : nil,
                isActive: viewModel.sideToMove == playerColor && isClockRunning,
                isThinking: false,
                capturedPieces: playerColor == .white ? captured.whiteCaptured : captured.blackCaptured,
                materialDiff: playerColor == .white ? max(0, captured.materialDiff) : max(0, -captured.materialDiff)
            )

            // Move list
            if viewModel.canGoBack {
                MoveListView(
                    game: viewModel.game,
                    currentIndex: viewModel.currentIndex
                ) { index in
                    // Only allow tapping to navigate when game is over
                    if gameOver {
                        navigateToIndex(index)
                    }
                }
                .padding(.horizontal, 4)
            }

            // Navigation bar (always visible — view-only during game)
            HStack(spacing: 20) {
                // Go to start
                Button { navigateViewOnly { viewModel.goToStart() } } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.body)
                        .frame(minWidth: 32, minHeight: 32)
                }
                .disabled(!viewModel.canGoBack)

                // Go back
                Button { navigateViewOnly { viewModel.goBack() } } label: {
                    Image(systemName: "chevron.backward")
                        .font(.body.weight(.semibold))
                        .frame(minWidth: 32, minHeight: 32)
                }
                .disabled(!viewModel.canGoBack)

                // Go forward
                Button { navigateViewOnly { viewModel.goForward() } } label: {
                    Image(systemName: "chevron.forward")
                        .font(.body.weight(.semibold))
                        .frame(minWidth: 32, minHeight: 32)
                }
                .disabled(!viewModel.canGoForward && !isViewingHistory)

                // Go to live / end
                Button { goToLive() } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.body)
                        .frame(minWidth: 32, minHeight: 32)
                }
                .disabled(!isViewingHistory && !viewModel.canGoForward)

                Spacer()

                // Undo (go back 2 moves: engine's + player's)
                if !gameOver {
                    Button { undoLastMove() } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.body)
                            .frame(minWidth: 32, minHeight: 32)
                    }
                    .disabled(isEngineThinking || !viewModel.canGoBack || isViewingHistory)
                }

                // Flip
                Button { viewModel.isFlipped.toggle() } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.body)
                        .frame(minWidth: 32, minHeight: 32)
                }

                // Resign
                if !gameOver {
                    Button { showResignConfirm = true } label: {
                        Image(systemName: "flag.fill")
                            .font(.body)
                            .foregroundStyle(.red)
                            .frame(minWidth: 32, minHeight: 32)
                    }
                    .disabled(isEngineThinking)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            // "Viewing history" indicator
            if isViewingHistory && !gameOver {
                Text("Viewing history — tap ▶▶ to return to game")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.bottom, 4)
            }

            Spacer(minLength: 0)
        }
        .background(Color(.systemGroupedBackground))
        .disableSwipeBack()
        .navigationBarBackButtonHidden(isClockRunning && !gameOver)
        .overlay {
            if gameOver {
                GameEndCard(
                    boardState: viewModel.boardState,
                    playerColor: playerColor,
                    onNewGame: { gameOver = false },
                    onDismiss: {}
                )
            }
        }
        .task {
            await setupGame()
        }
        .alert("Resign?", isPresented: $showResignConfirm) {
            Button("Resign", role: .destructive) { resign() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to resign this game?")
        }
        .onChange(of: viewModel.currentIndex) { old, new in
            guard !isNavigating, !isEngineThinking, !gameOver else { return }

            // Detect a player move: index advanced and it's now engine's turn
            let advanced = new.number > old.number ||
                (new.number == old.number && old.color == .white && new.color == .black) ||
                (new.number == old.number + 1 && old.color == .black && new.color == .white)

            if advanced && viewModel.sideToMove != playerColor {
                liveIndex = new
                Task { await engineMove() }
            }
        }
    }

    private func setupGame() async {
        playerColor = config.playerColor.resolvedColor
        viewModel.interactionMode = .play(as: playerColor)
        viewModel.isFlipped = playerColor == .black

        // Set up clocks
        if let tc = config.timeControl.timeAndIncrement {
            whiteTimeMs = tc.base * 1000
            blackTimeMs = tc.base * 1000
            incrementMs = tc.increment * 1000
            isTimed = true
        } else {
            isTimed = false
        }

        // Activate engine
        let descriptor = EngineDescriptor(
            id: UUID(),
            engineType: .stockfish,
            displayName: "Stockfish 17",
            uciOptions: [:],
            searchConfig: .infinite,
            isDefault: true,
            estimatedElo: config.engineElo
        )
        await engineRegistry.activate(descriptor: descriptor)

        // Configure for play: single PV, strength limiting
        if let engine = engineRegistry.engine {
            await engine.send(command: .setoption(id: "MultiPV", value: "1"))
            await engine.send(command: .setoption(id: "UCI_LimitStrength", value: "true"))
            await engine.send(command: .setoption(id: "UCI_Elo", value: "\(config.engineElo)"))
            // Send isready/readyok to ensure options are applied before first go
            await engine.send(command: .isready)
            try? await Task.sleep(for: .milliseconds(100))
        }

        // Start clocks if timed
        if isTimed {
            startClock()
        }

        liveIndex = viewModel.currentIndex

        // If engine plays white, make it move first
        if playerColor == .black {
            await engineMove()
        }
    }

    /// Depth limit based on Elo — lower Elo = shallower search for faster response.
    private var depthForElo: Int {
        let elo = config.engineElo
        if elo <= 800  { return 4 }
        if elo <= 1200 { return 6 }
        if elo <= 1600 { return 8 }
        if elo <= 2000 { return 10 }
        if elo <= 2400 { return 14 }
        return 20
    }

    private func engineMove() async {
        guard !gameOver else { return }
        isEngineThinking = true

        guard let engine = engineRegistry.engine else {
            isEngineThinking = false
            return
        }

        // Reset output before each move
        engineRegistry.output.reset()
        engineRegistry.output.isSearching = true

        // Stop any ongoing search and wait for its bestmove to flush
        await engine.send(command: .stop)
        try? await Task.sleep(for: .milliseconds(50))
        engineRegistry.output.bestMoveResult = nil  // Clear stale bestmove

        // Send current position
        let fen = viewModel.currentPosition.fen
        await engine.send(command: .position(.fen(fen)))

        // Go with appropriate limits
        if isTimed {
            await engine.send(command: .go(
                wtime: whiteTimeMs,
                btime: blackTimeMs,
                winc: incrementMs,
                binc: incrementMs
            ))
        } else {
            // Untimed: depth-limited search — fast and responsive at low Elo
            await engine.send(command: .go(depth: depthForElo))
        }

        // Wait for bestmove response
        let startTime = Date()
        while engineRegistry.output.bestMoveResult == nil {
            try? await Task.sleep(for: .milliseconds(50))
            if Date().timeIntervalSince(startTime) > 15 { break }
            if gameOver { break }
        }

        // Apply the engine's best move
        if let bestMove = engineRegistry.output.bestMoveResult {
            applyEngineMove(bestMove)

            // Add increment after engine move
            if isTimed {
                if viewModel.sideToMove == .white {
                    // Engine just moved as black
                    blackTimeMs += incrementMs
                } else {
                    whiteTimeMs += incrementMs
                }
            }
        }

        liveIndex = viewModel.currentIndex
        isEngineThinking = false
        checkGameEnd(viewModel.boardState)
    }

    private func applyEngineMove(_ lan: String) {
        // LAN format: e2e4, e7e8q (with promotion)
        guard lan.count >= 4 else { return }
        let fromNotation = String(lan.prefix(2))
        let toNotation = String(lan.dropFirst(2).prefix(2))
        let from = Square(fromNotation)
        let to = Square(toNotation)

        moveList.append(lan)

        if let _ = viewModel.makeMove(from: from, to: to) {
            // Handle promotion
            if lan.count == 5, viewModel.isPromotionPending {
                let promoChar = lan.last!
                let kind: Piece.Kind
                switch promoChar {
                case "q": kind = .queen
                case "r": kind = .rook
                case "b": kind = .bishop
                case "n": kind = .knight
                default: kind = .queen
                }
                viewModel.completePromotion(to: kind)
            }
        }
    }

    private func undoLastMove() {
        // Go back 2 moves (engine's move + player's move)
        if viewModel.canGoBack { viewModel.goBack() }  // Undo engine's move
        if viewModel.canGoBack { viewModel.goBack() }  // Undo player's move
        // Remove last 2 moves from the move list sent to engine
        if moveList.count >= 2 {
            moveList.removeLast(2)
        } else {
            moveList.removeAll()
        }
    }

    /// Whether the user is viewing a past position (not the live game position).
    private var isViewingHistory: Bool {
        guard let live = liveIndex else { return false }
        return viewModel.currentIndex != live
    }

    /// Navigate without triggering the engine.
    private func navigateViewOnly(_ action: () -> Void) {
        isNavigating = true
        action()
        isNavigating = false
    }

    /// Return to the live game position.
    private func goToLive() {
        if let live = liveIndex {
            navigateViewOnly {
                viewModel.goToStart()
                let history = viewModel.game.moves.history(for: live)
                for _ in history {
                    viewModel.goForward()
                }
            }
        } else {
            navigateViewOnly { viewModel.goToEnd() }
        }
    }

    private func navigateToIndex(_ index: MoveTree.Index) {
        navigateViewOnly {
            viewModel.goToStart()
            let history = viewModel.game.moves.history(for: index)
            for _ in history {
                viewModel.goForward()
            }
        }
    }

    private func startClock() {
        isClockRunning = true
        clockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard !gameOver, !isEngineThinking || isTimed else { return }
            if viewModel.sideToMove == .white {
                whiteTimeMs = max(0, whiteTimeMs - 100)
                if whiteTimeMs == 0 { checkGameEnd(viewModel.boardState) }
            } else {
                blackTimeMs = max(0, blackTimeMs - 100)
                if blackTimeMs == 0 { checkGameEnd(viewModel.boardState) }
            }
        }
    }

    private func resign() {
        gameOver = true
        isClockRunning = false
        clockTimer?.invalidate()
        Task { await engineRegistry.deactivate() }
        saveGame(result: playerColor == .white ? "0-1" : "1-0")
    }

    private func checkGameEnd(_ state: Board.State) {
        switch state {
        case .checkmate(let losingColor):
            gameOver = true
            isClockRunning = false
            clockTimer?.invalidate()
            let result = losingColor == .white ? "0-1" : "1-0"
            saveGame(result: result)
        case .draw:
            gameOver = true
            isClockRunning = false
            clockTimer?.invalidate()
            saveGame(result: "1/2-1/2")
        default:
            break
        }
    }

    private func saveGame(result: String) {
        let pgn = PGNExporter.export(game: viewModel.game)
        let record = GameRecord(
            white: playerColor == .white ? "You" : (engineRegistry.activeDescriptor?.displayName ?? "Engine"),
            black: playerColor == .black ? "You" : (engineRegistry.activeDescriptor?.displayName ?? "Engine"),
            result: result,
            pgn: pgn,
            source: .manual
        )
        modelContext.insert(record)
        try? modelContext.save()
    }
}

struct PlayerInfoBar: View {
    let name: String
    let elo: Int?
    let timeMs: Int?
    let isActive: Bool
    var isThinking: Bool = false
    var capturedPieces: String = ""
    var materialDiff: Int = 0

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(name)
                        .font(.subheadline.weight(.medium))
                    if let elo {
                        Text("(\(elo))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if isThinking {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }
                if !capturedPieces.isEmpty {
                    HStack(spacing: 1) {
                        Text(capturedPieces)
                            .font(.system(size: 12))
                        if materialDiff > 0 {
                            Text("+\(materialDiff)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer()
            if let timeMs {
                ClockView(timeMs: timeMs, isActive: isActive)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(isActive ? Color(.secondarySystemBackground) : .clear)
    }
}

/// Computes captured pieces and material difference from a position.
struct CapturedPiecesCalculator {
    static let startingCounts: [Piece.Kind: Int] = [
        .pawn: 8, .knight: 2, .bishop: 2, .rook: 2, .queen: 1, .king: 1
    ]

    static let pieceValues: [Piece.Kind: Int] = [
        .pawn: 1, .knight: 3, .bishop: 3, .rook: 5, .queen: 9, .king: 0
    ]

    static let pieceSymbols: [Piece.Kind: (white: String, black: String)] = [
        .pawn: ("♙", "♟"), .knight: ("♘", "♞"), .bishop: ("♗", "♝"),
        .rook: ("♖", "♜"), .queen: ("♕", "♛"), .king: ("♔", "♚")
    ]

    /// Returns (captured by white as string, captured by black as string, material diff).
    static func compute(from pieces: [Piece]) -> (whiteCaptured: String, blackCaptured: String, materialDiff: Int) {
        var whiteOnBoard: [Piece.Kind: Int] = [:]
        var blackOnBoard: [Piece.Kind: Int] = [:]

        for piece in pieces {
            if piece.color == .white {
                whiteOnBoard[piece.kind, default: 0] += 1
            } else {
                blackOnBoard[piece.kind, default: 0] += 1
            }
        }

        let order: [Piece.Kind] = [.queen, .rook, .bishop, .knight, .pawn]
        var whiteCaptured = ""  // Black pieces captured by white
        var blackCaptured = ""  // White pieces captured by black
        var whiteMaterial = 0
        var blackMaterial = 0

        for kind in order {
            let expected = startingCounts[kind] ?? 0
            let val = pieceValues[kind] ?? 0

            let whiteRemaining = whiteOnBoard[kind] ?? 0
            let blackRemaining = blackOnBoard[kind] ?? 0
            let whiteMissing = max(0, expected - whiteRemaining)
            let blackMissing = max(0, expected - blackRemaining)

            whiteMaterial += whiteRemaining * val
            blackMaterial += blackRemaining * val

            // White captured black's pieces
            for _ in 0..<blackMissing {
                whiteCaptured += pieceSymbols[kind]?.black ?? ""
            }
            // Black captured white's pieces
            for _ in 0..<whiteMissing {
                blackCaptured += pieceSymbols[kind]?.white ?? ""
            }
        }

        return (whiteCaptured, blackCaptured, whiteMaterial - blackMaterial)
    }
}

struct ClockView: View {
    let timeMs: Int
    let isActive: Bool

    var body: some View {
        Text(formattedTime)
            .font(.system(.title3, design: .monospaced).weight(.medium))
            .foregroundStyle(timeMs < 30_000 && isActive ? .red : .primary)
    }

    private var formattedTime: String {
        let totalSeconds = timeMs / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return String(format: "%d:%02d:%02d", hours, mins, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct GameEndCard: View {
    let boardState: Board.State
    let playerColor: Piece.Color
    let onNewGame: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(resultText)
                .font(.title2.weight(.bold))
            Text(detailText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("New Game") { onNewGame() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
        .padding()
    }

    private var resultText: String {
        switch boardState {
        case .checkmate(let color):
            return color == playerColor ? "You Lost" : "You Won!"
        case .draw:
            return "Draw"
        default:
            return "Game Over"
        }
    }

    private var detailText: String {
        switch boardState {
        case .checkmate:
            return "by checkmate"
        case .draw(let reason):
            switch reason {
            case .stalemate: return "by stalemate"
            case .fiftyMoves: return "by 50-move rule"
            case .repetition: return "by repetition"
            case .insufficientMaterial: return "by insufficient material"
            case .agreement: return "by agreement"
            }
        default:
            return ""
        }
    }
}
