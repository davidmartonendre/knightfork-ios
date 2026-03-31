import SwiftUI
import SwiftData

/// Home screen with primary actions.
struct HomeView: View {
    @Binding var selectedTab: Int
    @State private var showNewGame = false
    @State private var gameConfig: GameConfig?
    @Query(sort: \GameRecord.createdAt, order: .reverse) private var recentGames: [GameRecord]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        Button {
                            showNewGame = true
                        } label: {
                            ActionCard(
                                title: "New Game",
                                icon: "play.fill",
                                color: .blue
                            )
                        }

                        NavigationLink {
                            AnalysisView()
                        } label: {
                            ActionCard(
                                title: "Analyze",
                                icon: "magnifyingglass",
                                color: .purple
                            )
                        }

                        Button { selectedTab = 1 } label: {
                            ActionCard(
                                title: "My Games",
                                icon: "list.bullet",
                                color: .green
                            )
                        }

                        Button { selectedTab = 2 } label: {
                            ActionCard(
                                title: "Puzzles",
                                icon: "puzzlepiece.extension",
                                color: .orange
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Recent games
                    if !recentGames.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Games")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(recentGames.prefix(5)) { game in
                                NavigationLink {
                                    GameDetailView(record: game)
                                } label: {
                                    GameRowView(game: game)
                                        .padding(.horizontal)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.top)
            }
            .navigationTitle("KnightFork")
            .sheet(isPresented: $showNewGame) {
                NewGameSheet { config in
                    gameConfig = config
                }
            }
            .navigationDestination(item: $gameConfig) { config in
                PlayGameView(config: config)
            }
        }
    }
}

// Make GameConfig work with navigationDestination
extension GameConfig: Identifiable, Hashable {
    var id: String {
        "\(playerColor)-\(timeControl)-\(engineElo)-\(opening)"
    }

    static func == (lhs: GameConfig, rhs: GameConfig) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ActionCard: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
