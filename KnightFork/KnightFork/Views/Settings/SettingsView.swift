import SwiftUI
import SwiftData

/// Full settings screen.
struct SettingsView: View {
    @AppStorage("boardTheme") private var boardThemeId = "classicGreen"
    @AppStorage("showCoordinates") private var showCoordinates = true
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("defaultMultiPV") private var defaultMultiPV = 3
    @AppStorage("evalDisplay") private var evalDisplay = "centipawns"
    @AppStorage("autoStartEngine") private var autoStartEngine = true
    @AppStorage("lichessUsername") private var lichessUsername = ""
    @AppStorage("chesscomUsername") private var chesscomUsername = ""

    @Environment(\.modelContext) private var modelContext
    @State private var showSyncProgress = false
    @State private var syncStatus = ""

    var body: some View {
        NavigationStack {
            Form {
                // Board
                Section("Board") {
                    Picker("Theme", selection: $boardThemeId) {
                        ForEach(BoardTheme.allThemes) { theme in
                            Text(theme.name).tag(theme.id)
                        }
                    }
                    Toggle("Show Coordinates", isOn: $showCoordinates)
                    Toggle("Haptic Feedback", isOn: $hapticFeedback)
                }

                // Analysis
                Section("Analysis") {
                    Stepper("Default Engine Lines: \(defaultMultiPV)", value: $defaultMultiPV, in: 1...5)
                    Picker("Eval Display", selection: $evalDisplay) {
                        Text("Centipawns").tag("centipawns")
                        Text("Win %").tag("winpercent")
                    }
                    Toggle("Auto-start Engine", isOn: $autoStartEngine)
                }

                // Engines
                Section("Engines") {
                    NavigationLink {
                        EngineListView()
                    } label: {
                        Label("Manage Engines", systemImage: "cpu")
                    }
                }

                // Accounts
                Section("Accounts") {
                    HStack {
                        Text("Lichess")
                        Spacer()
                        TextField("Username", text: $lichessUsername)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }

                    if !lichessUsername.isEmpty {
                        Button("Sync Lichess Games") {
                            Task { await syncLichess() }
                        }
                    }

                    HStack {
                        Text("Chess.com")
                        Spacer()
                        TextField("Username", text: $chesscomUsername)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }

                    if !chesscomUsername.isEmpty {
                        Button("Sync Chess.com Games") {
                            Task { await syncChessCom() }
                        }
                    }

                    if !syncStatus.isEmpty {
                        Text(syncStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Data
                Section("Data") {
                    Button("Export All Games as PGN") {
                        exportAllGames()
                    }

                    Button("Clear Explorer Cache") {
                        // Clear cached API responses
                    }
                    .foregroundStyle(.orange)

                    Button("Reset All Data") {
                        // Dangerous — needs confirmation
                    }
                    .foregroundStyle(.red)
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    Link("GitHub Repository", destination: URL(string: "https://github.com")!)
                    Text("License: GPL-3.0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func syncLichess() async {
        syncStatus = "Syncing Lichess games..."
        do {
            let pgn = try await LichessAPIClient.shared.fetchGames(username: lichessUsername)
            let count = PGNImporter.importPGN(pgn, source: .lichess, into: modelContext)
            syncStatus = "Imported \(count) games from Lichess"
        } catch {
            syncStatus = "Lichess sync failed: \(error.localizedDescription)"
        }
    }

    private func syncChessCom() async {
        syncStatus = "Syncing Chess.com games..."
        do {
            let archives = try await ChessComAPIClient.shared.fetchArchives(username: chesscomUsername)
            var totalImported = 0

            // Get the last 3 months
            for archive in archives.suffix(3) {
                // Parse year/month from archive URL
                let parts = archive.split(separator: "/")
                guard parts.count >= 2,
                      let year = Int(parts[parts.count - 2]),
                      let month = Int(parts[parts.count - 1]) else { continue }

                let pgns = try await ChessComAPIClient.shared.fetchGames(username: chesscomUsername, year: year, month: month)
                let combined = pgns.joined(separator: "\n\n")
                let count = PGNImporter.importPGN(combined, source: .chesscom, into: modelContext)
                totalImported += count
            }

            syncStatus = "Imported \(totalImported) games from Chess.com"
        } catch {
            syncStatus = "Chess.com sync failed: \(error.localizedDescription)"
        }
    }

    private func exportAllGames() {
        // TODO: Query all games and export as combined PGN
    }
}
