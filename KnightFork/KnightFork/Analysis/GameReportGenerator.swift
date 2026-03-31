import Foundation
import Observation
import ChessKit
import ChessKitEngine
import OSLog

private let log = Logger(subsystem: "com.knightfork", category: "Report")

struct MoveAnalysis: Identifiable {
    let id: Int
    let moveNumber: Int
    let color: Piece.Color
    let playedMove: String
    let bestMove: String
    let scoreBefore: Double
    let scoreAfter: Double
    let winProbBefore: Double
    let winProbAfter: Double
    let winProbLoss: Double
    let accuracy: Double
    let annotation: MoveAnnotation
    let depth: Int
}

struct ReportProgress: Sendable {
    let current: Int
    let total: Int
    let phase: String
}

struct GameReport {
    let moves: [MoveAnalysis]
    let whiteAccuracy: Double
    let blackAccuracy: Double
    let depth: Int

    var whiteMoves: [MoveAnalysis] { moves.filter { $0.color == .white } }
    var blackMoves: [MoveAnalysis] { moves.filter { $0.color == .black } }
}

@Observable
final class GameReportGenerator {
    var isGenerating = false
    var progress: ReportProgress?
    var report: GameReport?
    var statusMessage: String = ""

    // Per-position state
    private var bestScore: Double = 0
    private var bestMoveLAN: String = ""
    private var secondBestScore: Double = 0
    private var bestMoveReceived = false

    private var task: Task<Void, Never>?

    func generate(game: Game, engine: Engine, viewModel: AnalysisViewModel, depth: Int = 10) {
        cancel()
        isGenerating = true
        statusMessage = "Preparing..."
        report = nil

        task = Task { [weak self] in
            guard let self else { return }

            var positions: [(index: MoveTree.Index, position: Position, move: Move)] = []

            let allIndices = game.moves.future(for: game.startingIndex)
            for idx in allIndices {
                guard let move = game.moves[idx] else { continue }
                // Use the game's cached position (previous index) — safe, no replay needed
                let prevIdx = idx.previous
                let position = game.positions[prevIdx] ?? .standard
                positions.append((index: idx, position: position, move: move))
            }

            let total = positions.count
            guard total > 0 else {
                await MainActor.run { self.statusMessage = "No moves"; self.isGenerating = false }
                return
            }

            log.info("Report: \(total) positions, depth \(depth)")

            // Take over response handling from analysis
            await MainActor.run { viewModel.isResponsePaused = true }
            await SharedEngine.shared.setResponseHandler { [weak self] response in
                Task { @MainActor in self?.handleResponse(response) }
            }

            // Stop current search and set MultiPV 2
            await engine.send(command: .stop)
            // Wait briefly for stop's bestmove
            try? await Task.sleep(for: .milliseconds(100))
            await engine.send(command: .setoption(id: "MultiPV", value: "2"))

            var analyses: [MoveAnalysis] = []

            for (i, entry) in positions.enumerated() {
                guard !Task.isCancelled else { break }

                await MainActor.run {
                    self.progress = ReportProgress(current: i + 1, total: total, phase: "Move \(i + 1)/\(total)")
                    self.statusMessage = "Move \(i + 1) of \(total)"
                    self.bestScore = 0
                    self.bestMoveLAN = ""
                    self.secondBestScore = 0
                    self.bestMoveReceived = false
                }

                let fen = entry.position.fen
                let sideToMove = entry.position.sideToMove

                await engine.send(command: .position(.fen(fen)))
                await engine.send(command: .go(depth: depth))

                // Wait for bestmove
                var waitMs = 0
                while await !MainActor.run(body: { self.bestMoveReceived }) {
                    try? await Task.sleep(for: .milliseconds(30))
                    waitMs += 30
                    if Task.isCancelled || waitMs > 30000 { break }
                }

                let best = await MainActor.run { self.bestScore }
                let bestLAN = await MainActor.run { self.bestMoveLAN }
                let second = await MainActor.run { self.secondBestScore }

                let normalizedBest = sideToMove == .white ? best : -best
                let normalizedSecond = sideToMove == .white ? second : -second

                let playedLAN = "\(entry.move.start.notation)\(entry.move.end.notation)"
                let playedMatchesBest = !bestLAN.isEmpty && String(bestLAN.prefix(4)) == playedLAN

                let wpBefore = AccuracyScorer.winProbability(cp: normalizedBest)
                let scoreAfter = playedMatchesBest ? normalizedBest : normalizedSecond
                let wpAfter = AccuracyScorer.winProbability(cp: scoreAfter)
                let wpLoss = playedMatchesBest ? 0 : max(0, wpBefore - wpAfter)
                let accuracy = AccuracyScorer.moveAccuracy(winProbLoss: wpLoss)
                let isOnlyGoodMove = abs(normalizedBest - normalizedSecond) > 150
                let annotation = MoveAnnotator.annotate(winProbLoss: wpLoss, isOnlyGoodMove: isOnlyGoodMove)

                log.debug("Move \(i+1) \(entry.move.san): played=\(playedLAN) best=\(bestLAN) loss=\(wpLoss) acc=\(accuracy)")

                analyses.append(MoveAnalysis(
                    id: i, moveNumber: entry.index.number, color: entry.index.color,
                    playedMove: entry.move.san, bestMove: bestLAN,
                    scoreBefore: normalizedBest, scoreAfter: scoreAfter,
                    winProbBefore: wpBefore, winProbAfter: wpAfter,
                    winProbLoss: wpLoss, accuracy: accuracy,
                    annotation: annotation, depth: depth
                ))
            }

            // Restore: give response handling back to analysis
            await engine.send(command: .stop)
            let mpv = await MainActor.run { viewModel.multiPV }
            await engine.send(command: .setoption(id: "MultiPV", value: "\(mpv)"))

            await SharedEngine.shared.setResponseHandler { [weak viewModel] response in
                Task { @MainActor in
                    guard let viewModel else { return }
                    // Re-route back to analysis handler
                    if !viewModel.isResponsePaused {
                        switch response {
                        case .info(let info): viewModel.output.update(from: info)
                        case .bestmove(let m, _):
                            viewModel.output.bestMoveResult = m
                            viewModel.output.isSearching = false
                        default: break
                        }
                    }
                }
            }
            await MainActor.run { viewModel.isResponsePaused = false }

            let whiteAcc = AccuracyScorer.overallAccuracy(perMoveAccuracies: analyses.filter { $0.color == .white }.map(\.accuracy))
            let blackAcc = AccuracyScorer.overallAccuracy(perMoveAccuracies: analyses.filter { $0.color == .black }.map(\.accuracy))

            log.info("Report complete: white=\(whiteAcc) black=\(blackAcc)")

            await MainActor.run {
                self.report = GameReport(moves: analyses, whiteAccuracy: whiteAcc, blackAccuracy: blackAcc, depth: depth)
                self.isGenerating = false
                self.statusMessage = ""
            }
        }
    }

    @MainActor
    private func handleResponse(_ response: EngineResponse) {
        switch response {
        case .info(let info):
            guard let score = info.score else { return }
            let cp = score.cp ?? (score.mate.map { $0 > 0 ? 10000.0 : -10000.0 } ?? 0)
            let mpv = info.multipv ?? 1
            if mpv == 1 {
                bestScore = cp
                if let pv = info.pv?.first { bestMoveLAN = pv }
            } else if mpv == 2 {
                secondBestScore = cp
            }
        case .bestmove:
            bestMoveReceived = true
        default:
            break
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isGenerating = false
        statusMessage = ""
    }
}
