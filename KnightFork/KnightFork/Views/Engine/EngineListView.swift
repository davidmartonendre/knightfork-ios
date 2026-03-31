import SwiftUI
import SwiftData
import ChessKitEngine

/// List of installed engines with configuration access.
struct EngineListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var engines: [EngineDescriptorModel]
    @State private var hasInitialized = false

    var body: some View {
        List {
            ForEach(engines) { engine in
                NavigationLink {
                    EngineDetailView(engine: engine)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(engine.displayName)
                                    .font(.body.weight(.medium))
                                if engine.isDefault {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                }
                            }
                            HStack(spacing: 8) {
                                Text("Bundled")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let elo = engine.estimatedElo {
                                    Text("~\(elo) Elo")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Engines")
        .task {
            if !hasInitialized && engines.isEmpty {
                initializeDefaultEngines()
                hasInitialized = true
            }
        }
    }

    private func initializeDefaultEngines() {
        let defaults = EngineRegistry.createDefaultDescriptors()
        for engine in defaults {
            modelContext.insert(engine)
        }
        try? modelContext.save()
    }
}

/// Detail view for configuring a single engine.
struct EngineDetailView: View {
    @Bindable var engine: EngineDescriptorModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Form {
            Section("General") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(engine.displayName)
                        .foregroundStyle(.secondary)
                }
                if let elo = engine.estimatedElo {
                    HStack {
                        Text("Estimated Elo")
                        Spacer()
                        Text("\(elo)")
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("Default Engine", isOn: $engine.isDefault)
                    .onChange(of: engine.isDefault) { _, isDefault in
                        if isDefault {
                            // Unset other defaults
                            clearOtherDefaults()
                        }
                        try? modelContext.save()
                    }
            }

            Section("Search Settings") {
                Picker("Default Search", selection: Binding(
                    get: { engine.searchDepth ?? 0 },
                    set: {
                        engine.searchDepth = $0 == 0 ? nil : $0
                        try? modelContext.save()
                    }
                )) {
                    Text("Infinite").tag(0)
                    Text("Depth 15").tag(15)
                    Text("Depth 20").tag(20)
                    Text("Depth 25").tag(25)
                    Text("Depth 30").tag(30)
                }
            }

            Section("UCI Options") {
                let options = engine.uciOptions
                if options.isEmpty {
                    Text("Using default engine settings")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(options.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                            Spacer()
                            Text(options[key] ?? "")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if engine.engineTypeName == "lc0" {
                Section {
                    Label("Experimental — may have performance issues on mobile", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle(engine.displayName)
    }

    private func clearOtherDefaults() {
        // This is a simplified approach
        // In practice, fetch all engines and unset their isDefault
    }
}
