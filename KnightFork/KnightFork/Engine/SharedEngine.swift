import Foundation
import ChessKitEngine
import UIKit
import OSLog

private let log = Logger(subsystem: "com.knightfork", category: "Engine")

/// Single shared Stockfish engine for the entire app.
/// Stockfish uses global C state — only ONE instance can exist.
/// Never call engine.stop() (kills the process). Use send(.stop) to halt searches.
actor SharedEngine {
    static let shared = SharedEngine()

    private var engine: Engine?
    private var listenerTask: Task<Void, Never>?
    private var responseHandler: ((EngineResponse) -> Void)?

    /// Get or create the single engine instance.
    func getEngine() async -> Engine {
        if let engine, await engine.isRunning {
            return engine
        }

        log.info("Creating shared Stockfish engine")
        let newEngine = Engine(type: .stockfish)
        self.engine = newEngine

        let coreCount = min(2, max(1, ProcessInfo.processInfo.activeProcessorCount - 1))
        await newEngine.start(coreCount: coreCount, multipv: 3)

        // Wait for engine to be ready
        for i in 0..<100 {
            if await newEngine.isRunning { break }
            try? await Task.sleep(for: .milliseconds(50))
            if i % 20 == 0 { log.debug("Waiting for engine... \(i * 50)ms") }
        }

        if await newEngine.isRunning {
            log.info("Shared engine ready")
        } else {
            log.error("Shared engine failed to start")
        }

        // Configure defaults
        let hashMB = await UIDevice.current.userInterfaceIdiom == .pad ? "128" : "64"
        await newEngine.send(command: .setoption(id: "Hash", value: hashMB))
        await newEngine.send(command: .setoption(id: "UCI_ShowWDL", value: "true"))

        // Start permanent response listener
        startListener(for: newEngine)

        return newEngine
    }

    /// Set the response handler (changes when switching between analysis/play/report).
    func setResponseHandler(_ handler: @escaping (EngineResponse) -> Void) {
        self.responseHandler = handler
    }

    private func startListener(for engine: Engine) {
        listenerTask?.cancel()
        listenerTask = Task { [weak self] in
            guard let stream = await engine.responseStream else {
                log.error("No response stream")
                return
            }
            log.info("Response listener started (permanent)")
            for await response in stream {
                guard !Task.isCancelled else { break }
                await self?.dispatchResponse(response)
            }
            log.info("Response listener ended")
        }
    }

    private func dispatchResponse(_ response: EngineResponse) {
        responseHandler?(response)
    }
}
