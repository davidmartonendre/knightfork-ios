import SwiftUI
import ChessKit

/// Configuration for a new game vs engine.
struct GameConfig {
    var playerColor: PlayerColorChoice = .random
    var timeControl: TimeControlOption = .rapid10
    var engineElo: Int = 1500
    var opening: OpeningChoice = .standard

    enum PlayerColorChoice: String, CaseIterable {
        case white = "White"
        case black = "Black"
        case random = "Random"

        var resolvedColor: Piece.Color {
            switch self {
            case .white: return .white
            case .black: return .black
            case .random: return Bool.random() ? .white : .black
            }
        }
    }

    enum OpeningChoice: String, CaseIterable {
        case standard = "Standard"
        case chess960 = "Chess960"
    }
}

/// Time control presets.
enum TimeControlOption: String, CaseIterable, Identifiable {
    case none = "None"
    case bullet1 = "1+0"
    case bullet2 = "2+1"
    case blitz3 = "3+0"
    case blitz3inc = "3+2"
    case blitz5 = "5+0"
    case blitz5inc = "5+3"
    case rapid10 = "10+0"
    case rapid15 = "15+10"
    case rapid30 = "30+0"
    case classical = "60+30"

    var id: String { rawValue }

    /// Base time in seconds, increment in seconds.
    var timeAndIncrement: (base: Int, increment: Int)? {
        switch self {
        case .none: return nil
        case .bullet1: return (60, 0)
        case .bullet2: return (120, 1)
        case .blitz3: return (180, 0)
        case .blitz3inc: return (180, 2)
        case .blitz5: return (300, 0)
        case .blitz5inc: return (300, 3)
        case .rapid10: return (600, 0)
        case .rapid15: return (900, 10)
        case .rapid30: return (1800, 0)
        case .classical: return (3600, 30)
        }
    }

    var category: String {
        switch self {
        case .none: return "Untimed"
        case .bullet1, .bullet2: return "Bullet"
        case .blitz3, .blitz3inc, .blitz5, .blitz5inc: return "Blitz"
        case .rapid10, .rapid15, .rapid30: return "Rapid"
        case .classical: return "Classical"
        }
    }
}

/// Sheet for configuring a new game against the engine.
struct NewGameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config = GameConfig()
    var onStart: (GameConfig) -> Void

    var body: some View {
        NavigationStack {
            Form {
                // Color
                Section("Play as") {
                    Picker("Color", selection: $config.playerColor) {
                        ForEach(GameConfig.PlayerColorChoice.allCases, id: \.self) { choice in
                            Text(choice.rawValue).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Time Control
                Section("Time Control") {
                    Picker("Time", selection: $config.timeControl) {
                        ForEach(TimeControlOption.allCases) { option in
                            Text("\(option.category) \(option.rawValue)")
                                .tag(option)
                        }
                    }
                }

                // Engine Strength
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Engine Strength")
                            Spacer()
                            Text("~\(config.engineElo) Elo")
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(config.engineElo) },
                                set: { config.engineElo = Int($0) }
                            ),
                            in: 400...3200,
                            step: 50
                        )
                    }
                }

                // Opening
                Section("Opening") {
                    Picker("Opening", selection: $config.opening) {
                        ForEach(GameConfig.OpeningChoice.allCases, id: \.self) { choice in
                            Text(choice.rawValue).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Start") {
                        dismiss()
                        onStart(config)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
