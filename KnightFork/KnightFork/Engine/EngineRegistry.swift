import Foundation
import Observation
import ChessKitEngine
import UIKit

/// Central engine management service.
/// Manages engine lifecycle, configuration, and hot-swapping.
@Observable
final class EngineRegistry {
    static let shared = EngineRegistry()

    private(set) var activeDescriptor: EngineDescriptor?
    private(set) var engine: Engine?
    private(set) var isRunning = false

    let output = EngineOutput()

    private init() {}

    // MARK: - Engine Lifecycle

    /// Activate an engine with the given descriptor.
    func activate(descriptor: EngineDescriptor) async {
        await deactivate()

        // Use the shared single engine
        let eng = await SharedEngine.shared.getEngine()
        self.engine = eng
        self.activeDescriptor = descriptor

        // Set our response handler
        await SharedEngine.shared.setResponseHandler { [weak self] response in
            Task { @MainActor in self?.handleResponse(response) }
        }

        // Configure for play
        if descriptor.engineType == .stockfish {
            await eng.send(command: .setoption(id: "Move Overhead", value: "50"))
        }

        isRunning = true
    }

    /// Stop the active engine search (does NOT destroy the engine process).
    func deactivate() async {
        isRunning = false

        if let eng = engine {
            await eng.send(command: .stop)
        }

        engine = nil
        activeDescriptor = nil
        output.reset()
    }

    /// Hot-swap to a different engine.
    func hotSwap(to descriptor: EngineDescriptor) async {
        await deactivate()
        await activate(descriptor: descriptor)
    }

    // MARK: - Commands

    /// Send a position and start searching.
    func analyze(fen: String, searchConfig: SearchConfig? = nil) async {
        guard let engine, isRunning else { return }
        output.reset()
        output.isSearching = true

        await engine.send(command: .stop)
        await engine.send(command: .position(.fen(fen)))

        let config = searchConfig ?? activeDescriptor?.searchConfig ?? .infinite
        switch config {
        case .infinite:
            await engine.send(command: .go(infinite: true))
        case .depth(let d):
            await engine.send(command: .go(depth: d))
        case .time(let seconds):
            await engine.send(command: .go(movetime: seconds * 1000))
        case .nodes(let n):
            await engine.send(command: .go(nodes: n))
        }
    }

    /// Send position and go with time controls (for play vs engine).
    func goWithClock(
        fen: String,
        moves: [String],
        wtime: Int,
        btime: Int,
        winc: Int = 0,
        binc: Int = 0
    ) async {
        guard let engine, isRunning else { return }

        output.reset()
        output.isSearching = true

        await engine.send(command: .stop)
        if moves.isEmpty {
            await engine.send(command: .position(.fen(fen)))
        } else {
            await engine.send(command: .position(.startpos, moves: moves))
        }
        await engine.send(command: .go(
            wtime: wtime,
            btime: btime,
            winc: winc,
            binc: binc
        ))
    }

    /// Stop the current search.
    func stopSearch() async {
        guard let engine else { return }
        await engine.send(command: .stop)
        output.isSearching = false
    }

    /// Set UCI option on the active engine.
    func setOption(id: String, value: String) async {
        guard let engine else { return }
        await engine.send(command: .setoption(id: id, value: value))
    }

    /// Set strength limiting for play mode.
    func setStrength(elo: Int) async {
        guard let engine else { return }
        await engine.send(command: .setoption(id: "UCI_LimitStrength", value: "true"))
        await engine.send(command: .setoption(id: "UCI_Elo", value: "\(elo)"))
    }

    /// Clear strength limiting.
    func clearStrengthLimit() async {
        guard let engine else { return }
        await engine.send(command: .setoption(id: "UCI_LimitStrength", value: "false"))
    }

    // MARK: - Private

    private func handleResponse(_ response: EngineResponse) {
        switch response {
        case .info(let info):
            output.update(from: info)
        case .bestmove(let move, let ponder):
            output.bestMoveResult = move
            output.ponderMove = ponder
            output.isSearching = false
        case .readyok:
            isRunning = true
        default:
            break
        }
    }

    private var deviceCoreCount: Int {
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let target = isIPad ? 4 : 2
        return min(target, max(1, cores - 1))
    }

    // MARK: - Default Engine Setup

    /// Create default engine descriptors on first launch.
    static func createDefaultDescriptors() -> [EngineDescriptorModel] {
        let stockfish = EngineDescriptorModel(
            engineTypeName: "stockfish",
            displayName: "Stockfish 17",
            isDefault: true,
            estimatedElo: 3500
        )

        let lc0 = EngineDescriptorModel(
            engineTypeName: "lc0",
            displayName: "Leela Chess Zero",
            isDefault: false,
            estimatedElo: 3200
        )

        return [stockfish, lc0]
    }
}
