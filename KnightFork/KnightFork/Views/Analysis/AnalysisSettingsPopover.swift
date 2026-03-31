import SwiftUI

/// Quick settings for analysis mode.
struct AnalysisSettingsPopover: View {
    @Bindable var viewModel: AnalysisViewModel

    var body: some View {
        Form {
            Section("Engine Lines") {
                Picker("Number of lines", selection: Binding(
                    get: { viewModel.multiPV },
                    set: { newVal in
                        Task { await viewModel.setMultiPV(newVal) }
                    }
                )) {
                    ForEach(1...5, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Depth Limit") {
                Picker("Depth", selection: Binding(
                    get: { viewModel.depthLimit ?? 0 },
                    set: { newVal in
                        Task { await viewModel.setDepthLimit(newVal == 0 ? nil : newVal) }
                    }
                )) {
                    Text("Infinite").tag(0)
                    Text("15").tag(15)
                    Text("20").tag(20)
                    Text("25").tag(25)
                    Text("30").tag(30)
                    Text("40").tag(40)
                }
            }

            Section {
                Button(viewModel.isEngineOn ? "Turn Off Engine" : "Turn On Engine") {
                    Task { await viewModel.toggleEngine() }
                }
                .foregroundStyle(viewModel.isEngineOn ? .red : .accentColor)
            }
        }
        .frame(minWidth: 280, minHeight: 200)
    }
}
