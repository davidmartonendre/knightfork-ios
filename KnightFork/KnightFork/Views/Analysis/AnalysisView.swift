import SwiftUI
import ChessKit
import ChessKitEngine
import UIKit

/// Main analysis screen with eval bar, board, engine lines, explorer, and move list.
struct AnalysisView: View {
    @State private var viewModel: AnalysisViewModel
    @State private var explorerVM = ExplorerViewModel()
    @State private var reportGenerator = GameReportGenerator()
    @State private var showSettings = false
    @State private var showExplorer = true
    @State private var showReport = false

    init(game: Game = Game()) {
        let boardVM = BoardViewModel(game: game)
        boardVM.interactionMode = .analysis
        _viewModel = State(initialValue: AnalysisViewModel(boardViewModel: boardVM))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Eval bar + Board row
            HStack(spacing: 0) {
                if viewModel.isEngineOn {
                    EvalBar(
                        score: viewModel.output.bestLine?.score,
                        depth: viewModel.output.currentDepth,
                        sideToMove: viewModel.boardViewModel.sideToMove
                    )
                    .padding(.leading, 4)
                }

                ChessBoardView(viewModel: viewModel.boardViewModel)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, 4)
            }

            // Engine lines or status
            if reportGenerator.isGenerating {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text(reportGenerator.statusMessage.isEmpty ? "Generating report..." : reportGenerator.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if viewModel.isEngineOn {
                EngineLinesPanel(
                    lines: viewModel.output.lines,
                    isSearching: viewModel.output.isSearching,
                    sideToMove: viewModel.boardViewModel.sideToMove
                )
                .frame(maxHeight: 80)
                .padding(.horizontal, 4)
            } else if !viewModel.engineStatus.isEmpty {
                Text(viewModel.engineStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            // Explorer panel (collapsible)
            if showExplorer {
                ExplorerPanel(
                    moves: explorerVM.moves,
                    opening: explorerVM.opening,
                    isLoading: explorerVM.isLoading,
                    isTablebase: explorerVM.isTablebase,
                    tablebaseMoves: explorerVM.tablebaseMoves,
                    source: explorerVM.source,
                    onSourceChanged: { explorerVM.changeSource($0) },
                    onMoveTapped: { san in
                        // Play the explorer move on the board
                        playMoveSAN(san)
                    }
                )
                .frame(maxHeight: 120)
                .padding(.horizontal, 4)
            }

            // Move list
            MoveListView(
                game: viewModel.boardViewModel.game,
                currentIndex: viewModel.boardViewModel.currentIndex
            ) { index in
                navigateTo(index)
            }
            .padding(.horizontal, 4)

            // Navigation + tool buttons (two rows to avoid overflow)
            NavigationBar(viewModel: viewModel.boardViewModel) {
                viewModel.boardViewModel.isFlipped.toggle()
            }

            // Tool buttons row
            HStack(spacing: 20) {
                // Explorer toggle
                Button {
                    showExplorer.toggle()
                } label: {
                    Image(systemName: "book")
                        .font(.body)
                        .foregroundStyle(showExplorer ? .blue : .secondary)
                        .frame(minWidth: 32, minHeight: 28)
                }

                // Engine toggle
                Button {
                    Task { await viewModel.toggleEngine() }
                } label: {
                    Image(systemName: viewModel.isEngineOn ? "bolt.fill" : "bolt.slash")
                        .font(.body)
                        .foregroundStyle(viewModel.isEngineOn ? .green : .secondary)
                        .frame(minWidth: 32, minHeight: 28)
                }

                // Report
                Button {
                    if reportGenerator.report != nil {
                        showReport = true
                    } else if !reportGenerator.isGenerating, let engine = viewModel.engine {
                        reportGenerator.generate(
                            game: viewModel.boardViewModel.game,
                            engine: engine,
                            viewModel: viewModel
                        )
                    }
                } label: {
                    if reportGenerator.isGenerating {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: "chart.bar")
                            .font(.body)
                            .foregroundStyle(reportGenerator.report != nil ? .orange : .secondary)
                            .frame(minWidth: 32, minHeight: 28)
                    }
                }

                // Settings
                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.body)
                        .frame(minWidth: 32, minHeight: 28)
                }
                .popover(isPresented: $showSettings) {
                    AnalysisSettingsPopover(viewModel: viewModel)
                        .presentationCompactAdaptation(.popover)
                }
            }
            .padding(.horizontal)

            // Report progress/status
            if reportGenerator.isGenerating {
                HStack {
                    if let progress = reportGenerator.progress {
                        ProgressView(value: Double(progress.current), total: Double(progress.total))
                        Text(progress.phase)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView().scaleEffect(0.7)
                        Text(reportGenerator.statusMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            } else if !reportGenerator.statusMessage.isEmpty {
                Text(reportGenerator.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
            }

            Spacer(minLength: 0)
        }
        .background(Color(.systemGroupedBackground))
        .disableSwipeBack()
        .onChange(of: viewModel.boardViewModel.currentPosition.fen) { _, _ in
            viewModel.onPositionChanged()
            explorerVM.fetchForPosition(fen: viewModel.boardViewModel.currentPosition.fen)
        }
        .onChange(of: viewModel.output.lines) { _, lines in
            updateBoardArrows(lines)
        }
        .task {
            await viewModel.startEngine()
            explorerVM.fetchForPosition(fen: viewModel.boardViewModel.currentPosition.fen)
        }
        .onDisappear {
            // Stop search but keep engine alive (Stockfish C global state)
            Task {
                if let engine = viewModel.engine {
                    await engine.send(command: .stop)
                }
            }
        }
        .sheet(isPresented: $showReport) {
            if let report = reportGenerator.report {
                NavigationStack {
                    ReportView(report: report, game: viewModel.boardViewModel.game) { moveId in
                        showReport = false
                        // Navigate to that move (moveId is 0-based, need moveId+1 forwards)
                        let boardVM = viewModel.boardViewModel
                        boardVM.goToStart()
                        for _ in 0...moveId {
                            boardVM.goForward()
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showReport = false }
                        }
                    }
                }
            }
        }
        .onChange(of: reportGenerator.report != nil) { _, hasReport in
            if hasReport {
                showReport = true
                // Analysis resumes automatically — report restores the response handler
                Task { await viewModel.analyzeCurrentPosition() }
            }
        }
    }

    private func navigateTo(_ index: MoveTree.Index) {
        let boardVM = viewModel.boardViewModel
        let history = boardVM.game.moves.history(for: index)
        boardVM.goToStart()
        for _ in history {
            boardVM.goForward()
        }
    }

    private func playMoveSAN(_ san: String) {
        // Try to make the move on the board
        let position = viewModel.boardViewModel.currentPosition
        let board = Board(position: position)
        // Find which piece can make this SAN move
        for piece in position.pieces {
            if piece.color == position.sideToMove {
                let legalMoves = board.legalMoves(forPieceAt: piece.square)
                for dest in legalMoves {
                    // Try the move and check if its SAN matches
                    var testBoard = board
                    if let move = testBoard.move(pieceAt: piece.square, to: dest) {
                        if move.san == san {
                            viewModel.boardViewModel.makeMove(from: piece.square, to: dest)
                            return
                        }
                    }
                }
            }
        }
    }

    private func updateBoardArrows(_ lines: [EngineLine]) {
        let colors: [UIColor] = [
            UIColor.systemGreen.withAlphaComponent(0.6),
            UIColor.systemBlue.withAlphaComponent(0.4),
            UIColor.systemGray.withAlphaComponent(0.3)
        ]
        var arrows: [(from: Square, to: Square, color: UIColor)] = []

        for (i, line) in lines.prefix(3).enumerated() {
            guard let firstMove = line.pv.first, firstMove.count >= 4 else { continue }
            let fromStr = String(firstMove.prefix(2))
            let toStr = String(firstMove.dropFirst(2).prefix(2))
            let from = Square(fromStr)
            let to = Square(toStr)
            arrows.append((from: from, to: to, color: colors[min(i, colors.count - 1)]))
        }

        viewModel.boardViewModel.analysisArrows = arrows
    }
}
