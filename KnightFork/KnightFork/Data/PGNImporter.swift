import Foundation
import ChessKit
import SwiftData

/// Progress update during PGN import.
struct ImportProgress: Sendable {
    let current: Int
    let total: Int
    let lastPlayerNames: String
}

/// Imports single or multi-game PGN files into the database.
struct PGNImporter {

    /// Parse a PGN string that may contain multiple games.
    /// Returns an array of parsed Game objects along with their raw PGN text.
    static func parseMultiGamePGN(_ pgnText: String) -> [(game: Game, rawPGN: String)] {
        var results: [(Game, String)] = []

        // Split on double newlines followed by a tag (heuristic for multi-game PGN)
        let games = splitPGNGames(pgnText)

        for gamePGN in games {
            let trimmed = gamePGN.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            do {
                let game = try PGNParser.parse(game: trimmed)
                results.append((game, trimmed))
            } catch {
                // Skip unparseable games (lenient parsing per spec)
                continue
            }
        }

        return results
    }

    /// Import a PGN string into SwiftData, creating GameRecord entries.
    @MainActor
    static func importPGN(
        _ pgnText: String,
        source: GameSource = .pgn,
        into modelContext: ModelContext,
        progress: ((ImportProgress) -> Void)? = nil
    ) -> Int {
        let parsed = parseMultiGamePGN(pgnText)
        let total = parsed.count

        for (index, entry) in parsed.enumerated() {
            let game = entry.game
            let tags = game.tags

            let record = GameRecord(
                white: tags.white.isEmpty ? "?" : tags.white,
                black: tags.black.isEmpty ? "?" : tags.black,
                date: parseDate(tags.date),
                result: tags.result.isEmpty ? "*" : tags.result,
                event: tags.event,
                site: tags.site,
                eco: tags.other["ECO"] ?? "",
                pgn: entry.rawPGN,
                timeControl: tags.timeControl,
                source: source,
                whiteElo: Int(tags.other["WhiteElo"] ?? ""),
                blackElo: Int(tags.other["BlackElo"] ?? "")
            )

            modelContext.insert(record)

            if index % 50 == 0 {
                progress?(ImportProgress(
                    current: index + 1,
                    total: total,
                    lastPlayerNames: "\(record.white) vs \(record.black)"
                ))
            }
        }

        // Batch save
        try? modelContext.save()

        return total
    }

    // MARK: - Private Helpers

    /// Split a multi-game PGN string into individual game strings.
    private static func splitPGNGames(_ text: String) -> [String] {
        var games: [String] = []
        var current = ""
        var inMoveText = false

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("[") && inMoveText {
                // New game starting — save current
                if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    games.append(current)
                }
                current = ""
                inMoveText = false
            }

            if !trimmed.hasPrefix("[") && !trimmed.isEmpty && !inMoveText {
                inMoveText = true
            }

            current += line + "\n"
        }

        // Don't forget the last game
        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            games.append(current)
        }

        return games
    }

    /// Parse a PGN date string (YYYY.MM.DD) into a Date.
    private static func parseDate(_ dateStr: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.date(from: dateStr) ?? Date()
    }
}
