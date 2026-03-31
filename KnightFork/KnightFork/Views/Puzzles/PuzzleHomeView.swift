import SwiftUI

/// Puzzle home screen — configure difficulty/theme and start solving.
struct PuzzleHomeView: View {
    @State private var difficulty: PuzzleDifficulty = .normal
    @State private var theme: PuzzleThemeOption = .mix

    var body: some View {
        NavigationStack {
            List {
                difficultySection
                themeSection
                startSection
            }
            .navigationTitle("Puzzles")
        }
    }

    // MARK: - Sections

    private var difficultySection: some View {
        Section("Difficulty") {
            Picker("Difficulty", selection: $difficulty) {
                ForEach(PuzzleDifficulty.allCases) { d in
                    Text(d.displayName).tag(d)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    private var themeSection: some View {
        Section("Theme") {
            Picker("Theme", selection: $theme) {
                let grouped = Dictionary(grouping: PuzzleThemeOption.allCases, by: \.group)
                let order = ["General", "Tactics", "Checkmate", "Patterns", "Phase", "Special Moves", "Advantage", "Length"]

                ForEach(order, id: \.self) { group in
                    if let items = grouped[group] {
                        Section(group) {
                            ForEach(items) { t in
                                Text(t.displayName).tag(t)
                            }
                        }
                    }
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    private var startSection: some View {
        Section {
            NavigationLink {
                PuzzleSolveView(
                    initialDifficulty: difficulty,
                    initialTheme: theme
                )
            } label: {
                HStack {
                    Spacer()
                    Label("Start Solving", systemImage: "play.fill")
                        .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            NavigationLink {
                DailyPuzzleView()
            } label: {
                Label("Daily Puzzle", systemImage: "calendar")
            }
        }
    }
}
