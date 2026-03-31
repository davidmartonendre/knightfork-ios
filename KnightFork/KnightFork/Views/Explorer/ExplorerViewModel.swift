import Foundation
import Observation
import ChessKit

/// Manages explorer data fetching and state.
@Observable
final class ExplorerViewModel {
    var moves: [ExplorerMove] = []
    var opening: ExplorerOpening?
    var tablebaseMoves: [TablebaseMove] = []
    var isLoading = false
    var isTablebase = false
    var source: ExplorerSource = .masters
    var error: String?

    private var currentFEN: String = ""
    private var fetchTask: Task<Void, Never>?

    func fetchForPosition(fen: String) {
        guard fen != currentFEN else { return }
        currentFEN = fen

        fetchTask?.cancel()
        fetchTask = Task {
            await performFetch(fen: fen)
        }
    }

    func changeSource(_ newSource: ExplorerSource) {
        source = newSource
        let fen = currentFEN
        currentFEN = "" // Force refetch
        fetchForPosition(fen: fen)
    }

    private func performFetch(fen: String) async {
        await MainActor.run { isLoading = true; error = nil }
        defer { Task { @MainActor in isLoading = false } }

        let pieces = TablebaseClient.pieceCount(fen: fen)
        if pieces <= 7 {
            do {
                let result = try await TablebaseClient.shared.probe(fen: fen)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    tablebaseMoves = result.moves
                    isTablebase = true
                    moves = []
                    opening = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.error = "Tablebase unavailable"
                    isTablebase = false
                }
            }
        } else {
            await MainActor.run { isTablebase = false; tablebaseMoves = [] }
            do {
                let result = try await LichessExplorerClient.shared.explore(fen: fen, source: source)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    moves = result.moves
                    opening = result.opening
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("[Explorer] Error fetching \(fen): \(error)")
                await MainActor.run {
                    self.error = "Explorer: \(error.localizedDescription)"
                    moves = []
                    opening = nil
                }
            }
        }
    }
}
