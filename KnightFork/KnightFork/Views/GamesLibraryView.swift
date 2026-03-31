import SwiftUI
import SwiftData
import ChessKit

/// Searchable, sortable list of all imported/played games.
struct GamesLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GameRecord.date, order: .reverse) private var games: [GameRecord]
    @State private var searchText = ""
    @State private var showingImport = false
    @State private var selectedGame: GameRecord?

    var body: some View {
        NavigationStack {
            Group {
                if games.isEmpty {
                    ContentUnavailableView {
                        Label("No Games", systemImage: "list.bullet")
                    } description: {
                        Text("Import PGN files or play a game to get started.")
                    } actions: {
                        Button("Import PGN") { showingImport = true }
                    }
                } else {
                    List {
                        ForEach(filteredGames) { game in
                            NavigationLink {
                                GameDetailView(record: game)
                            } label: {
                                GameRowView(game: game)
                            }
                        }
                        .onDelete(perform: deleteGames)
                    }
                    .searchable(text: $searchText, prompt: "Search players, openings...")
                }
            }
            .navigationTitle("Games")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingImport = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $showingImport) {
                ImportSheet()
            }
        }
    }

    private var filteredGames: [GameRecord] {
        if searchText.isEmpty { return games }
        let query = searchText.lowercased()
        return games.filter {
            $0.white.lowercased().contains(query) ||
            $0.black.lowercased().contains(query) ||
            $0.eco.lowercased().contains(query) ||
            $0.event.lowercased().contains(query)
        }
    }

    private func deleteGames(at offsets: IndexSet) {
        for index in offsets {
            let game = filteredGames[index]
            modelContext.delete(game)
        }
        try? modelContext.save()
    }
}

struct GameRowView: View {
    let game: GameRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(game.white)
                    .fontWeight(.medium)
                Text("vs")
                    .foregroundStyle(.secondary)
                Text(game.black)
                    .fontWeight(.medium)
                Spacer()
                Text(game.result)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(resultColor)
            }

            HStack {
                if !game.eco.isEmpty {
                    Text(game.eco)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !game.event.isEmpty {
                    Text(game.event)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(game.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                sourceIcon
            }
        }
        .padding(.vertical, 2)
    }

    private var resultColor: Color {
        switch game.result {
        case "1-0": return .primary
        case "0-1": return .primary
        case "1/2-1/2": return .secondary
        default: return .secondary
        }
    }

    @ViewBuilder
    private var sourceIcon: some View {
        switch game.source {
        case .lichess:
            Image(systemName: "globe")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .chesscom:
            Image(systemName: "globe.americas")
                .font(.caption2)
                .foregroundStyle(.green)
        case .pgn:
            Image(systemName: "doc.text")
                .font(.caption2)
                .foregroundStyle(.blue)
        case .manual:
            Image(systemName: "hand.draw")
                .font(.caption2)
                .foregroundStyle(.purple)
        }
    }
}

/// Opens a game from a record in the full analysis view.
struct GameDetailView: View {
    let record: GameRecord
    @State private var game: Game?

    var body: some View {
        Group {
            if let game {
                AnalysisView(game: game)
                    .navigationTitle("\(record.white) vs \(record.black)")
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                ProgressView("Loading game...")
                    .task { loadGame() }
            }
        }
    }

    private func loadGame() {
        let pgn = record.annotatedPGN ?? record.pgn
        guard !pgn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            game = Game()
            return
        }
        do {
            game = try PGNParser.parse(game: pgn)
        } catch {
            game = Game()
        }
    }
}
