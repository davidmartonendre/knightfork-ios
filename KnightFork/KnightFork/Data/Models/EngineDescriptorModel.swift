import Foundation
import SwiftData

/// Persisted engine configuration.
@Model
final class EngineDescriptorModel {
    @Attribute(.unique) var id: UUID
    var engineTypeName: String  // "stockfish" or "lc0"
    var displayName: String
    var uciOptionsJSON: Data?   // Serialized [String: String]
    var searchDepth: Int?       // Default search depth (nil = infinite)
    var isDefault: Bool
    var estimatedElo: Int?

    init(
        id: UUID = UUID(),
        engineTypeName: String,
        displayName: String,
        isDefault: Bool = false,
        estimatedElo: Int? = nil,
        searchDepth: Int? = nil
    ) {
        self.id = id
        self.engineTypeName = engineTypeName
        self.displayName = displayName
        self.isDefault = isDefault
        self.estimatedElo = estimatedElo
        self.searchDepth = searchDepth
    }

    // MARK: - UCI Options Helpers

    var uciOptions: [String: String] {
        get {
            guard let data = uciOptionsJSON else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            uciOptionsJSON = try? JSONEncoder().encode(newValue)
        }
    }
}
