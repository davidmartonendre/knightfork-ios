import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Sheet for importing PGN files or pasting FEN positions.
struct ImportSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showFilePicker = false
    @State private var fenText = ""
    @State private var importResult: String?
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            List {
                // PGN File Import
                Section {
                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Import PGN File", systemImage: "doc.text")
                    }
                    .disabled(isImporting)
                } header: {
                    Text("PGN Import")
                } footer: {
                    Text("Import single or multi-game PGN files from the Files app.")
                }

                // Paste PGN
                Section {
                    Button {
                        pasteFromClipboard()
                    } label: {
                        Label("Paste PGN from Clipboard", systemImage: "doc.on.clipboard")
                    }
                    .disabled(isImporting)
                }

                // FEN Import
                Section {
                    TextField("Paste FEN string...", text: $fenText)
                        .font(.system(.caption, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if !fenText.isEmpty {
                        Button("Open Position") {
                            openFEN()
                        }
                    }
                } header: {
                    Text("FEN Position")
                } footer: {
                    Text("Paste a FEN string to set up a specific board position.")
                }

                // Import result
                if let result = importResult {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(result)
                        }
                    }
                }

                if isImporting {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Importing...")
                                .padding(.leading, 8)
                        }
                    }
                }
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.plainText, UTType(filenameExtension: "pgn") ?? .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        isImporting = true
        importResult = nil

        // Need to start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            importResult = "Could not access file"
            isImporting = false
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let pgnText = try String(contentsOf: url, encoding: .utf8)
            let count = PGNImporter.importPGN(pgnText, source: .pgn, into: modelContext)
            importResult = "Imported \(count) game\(count == 1 ? "" : "s")"
        } catch {
            importResult = "Error reading file: \(error.localizedDescription)"
        }

        isImporting = false
    }

    private func pasteFromClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            importResult = "Clipboard is empty"
            return
        }

        isImporting = true
        importResult = nil

        let count = PGNImporter.importPGN(text, source: .pgn, into: modelContext)
        importResult = "Imported \(count) game\(count == 1 ? "" : "s") from clipboard"
        isImporting = false
    }

    private func openFEN() {
        // For now, just dismiss — FEN opening will navigate to board
        // This will be wired up when we have proper navigation flow
        dismiss()
    }
}
