import Foundation
import ChessKitEngine

/// Search configuration for engine analysis.
enum SearchConfig: Equatable {
    case infinite
    case depth(Int)
    case time(seconds: Int)
    case nodes(Int)
}

/// Runtime engine configuration (loaded from SwiftData model).
struct EngineDescriptor: Identifiable, Equatable {
    let id: UUID
    let engineType: EngineType
    var displayName: String
    var uciOptions: [String: String]
    var searchConfig: SearchConfig
    var isDefault: Bool
    var estimatedElo: Int?

    static func fromModel(_ model: EngineDescriptorModel) -> EngineDescriptor {
        let type: EngineType = model.engineTypeName == "lc0" ? .lc0 : .stockfish
        let config: SearchConfig
        if let depth = model.searchDepth {
            config = .depth(depth)
        } else {
            config = .infinite
        }
        return EngineDescriptor(
            id: model.id,
            engineType: type,
            displayName: model.displayName,
            uciOptions: model.uciOptions,
            searchConfig: config,
            isDefault: model.isDefault,
            estimatedElo: model.estimatedElo
        )
    }
}
