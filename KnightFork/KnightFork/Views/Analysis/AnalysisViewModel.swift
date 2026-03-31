import Foundation
import Observation
import ChessKit
import ChessKitEngine
import UIKit
import OSLog

private let log = Logger(subsystem: "com.knightfork", category: "Analysis")

/// Coordinates the board, engine, and analysis UI.
/// Uses the shared single Stockfish engine.
@Observable
final class AnalysisViewModel {
    let boardViewModel: BoardViewModel

    let output = EngineOutput()
    var isEngineOn = false
    var multiPV = 3
    var depthLimit: Int? = nil
    var engineStatus: String = ""
    var isResponsePaused = false

    private(set) var engine: Engine?
    private var debounceTask: Task<Void, Never>?
    private var lastAnalyzedFEN: String = ""

    init(boardViewModel: BoardViewModel) {
        self.boardViewModel = boardViewModel
        self.boardViewModel.interactionMode = .analysis
    }

    // MARK: - Engine Control

    func startEngine() async {
        guard !isEngineOn else { return }
        engineStatus = "Starting engine..."

        let eng = await SharedEngine.shared.getEngine()
        self.engine = eng

        guard await eng.isRunning else {
            log.error("Engine not running after getEngine()")
            engineStatus = "Engine failed to start"
            return
        }

        // Set our response handler
        await SharedEngine.shared.setResponseHandler { [weak self] response in
            Task { @MainActor in
                self?.handleResponse(response)
            }
        }

        // Set MultiPV
        await eng.send(command: .setoption(id: "MultiPV", value: "\(multiPV)"))

        log.info("Engine started for analysis")
        isEngineOn = true
        engineStatus = ""
        await analyzeCurrentPosition()
    }

    func stopEngine() async {
        log.info("Pausing engine analysis")
        isEngineOn = false
        engineStatus = ""
        debounceTask?.cancel()

        if let eng = engine {
            await eng.send(command: .stop)
        }
        output.reset()
    }

    func toggleEngine() async {
        if isEngineOn {
            await stopEngine()
        } else {
            await startEngine()
        }
    }

    // MARK: - Analysis

    func onPositionChanged() {
        guard isEngineOn, !isResponsePaused else { return }
        let fen = boardViewModel.currentPosition.fen
        guard fen != lastAnalyzedFEN else { return }

        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            await analyzeCurrentPosition()
        }
    }

    func analyzeCurrentPosition() async {
        guard let engine, isEngineOn else {
            log.debug("analyzeCurrentPosition skipped")
            return
        }

        let fen = boardViewModel.currentPosition.fen
        lastAnalyzedFEN = fen

        output.reset()
        output.isSearching = true

        await engine.send(command: .stop)
        await engine.send(command: .position(.fen(fen)))

        switch depthLimit {
        case .some(let d):
            await engine.send(command: .go(depth: d))
        case .none:
            await engine.send(command: .go(infinite: true))
        }
    }

    // MARK: - Settings

    func setMultiPV(_ count: Int) async {
        multiPV = count
        guard let engine, isEngineOn else { return }
        log.info("Setting MultiPV to \(count)")
        await engine.send(command: .stop)
        await engine.send(command: .setoption(id: "MultiPV", value: "\(count)"))
        output.reset()
        lastAnalyzedFEN = ""
        await analyzeCurrentPosition()
    }

    func setDepthLimit(_ depth: Int?) async {
        depthLimit = depth
        guard isEngineOn else { return }
        await analyzeCurrentPosition()
    }

    // MARK: - Private

    private func handleResponse(_ response: EngineResponse) {
        if isResponsePaused {
            return  // Report generator handles responses directly via SharedEngine
        }

        switch response {
        case .info(let info):
            output.update(from: info)
        case .bestmove(let move, let ponder):
            output.bestMoveResult = move
            output.ponderMove = ponder
            output.isSearching = false
        default:
            break
        }
    }

    deinit {
        debounceTask?.cancel()
    }
}
