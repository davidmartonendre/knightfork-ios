import UIKit
import SpriteKit
import ChessKit

/// Provides piece textures for the board scene.
/// Uses pre-rasterized PNGs from the asset catalog, falling back to
/// SF Symbols as a development placeholder.
final class PieceImageProvider {
    static let shared = PieceImageProvider()

    private var textureCache: [String: SKTexture] = [:]

    private init() {}

    /// Returns a texture for the given piece kind and color.
    func texture(for kind: Piece.Kind, color: Piece.Color, squareSize: CGFloat) -> SKTexture {
        let key = "\(color)-\(kind)"
        if let cached = textureCache[key] {
            return cached
        }

        let tex: SKTexture
        if let image = assetImage(for: kind, color: color) {
            tex = SKTexture(image: image)
        } else {
            tex = fallbackTexture(for: kind, color: color, size: squareSize)
        }

        tex.filteringMode = .linear
        textureCache[key] = tex
        return tex
    }

    /// Clear the cache (e.g., on piece set change).
    func clearCache() {
        textureCache.removeAll()
    }

    // MARK: - Private

    private func assetImage(for kind: Piece.Kind, color: Piece.Color) -> UIImage? {
        let colorSuffix = color == .white ? "w" : "b"
        let kindName: String
        switch kind {
        case .king:   kindName = "king"
        case .queen:  kindName = "queen"
        case .rook:   kindName = "rook"
        case .bishop: kindName = "bishop"
        case .knight: kindName = "knight"
        case .pawn:   kindName = "pawn"
        }
        // Try loading from asset catalog (e.g., "knight-w", "queen-b")
        return UIImage(named: "\(kindName)-\(colorSuffix)")
    }

    private func fallbackTexture(for kind: Piece.Kind, color: Piece.Color, size: CGFloat) -> SKTexture {
        let symbolName: String
        switch kind {
        case .king:   symbolName = "crown.fill"
        case .queen:  symbolName = "star.fill"
        case .rook:   symbolName = "building.2.fill"
        case .bishop: symbolName = "shield.fill"
        case .knight: symbolName = "hare.fill"
        case .pawn:   symbolName = "circle.fill"
        }

        let displaySize = max(size * 0.7, 32)
        let config = UIImage.SymbolConfiguration(pointSize: displaySize, weight: .regular)
        let tintColor: UIColor = color == .white
            ? UIColor(white: 1.0, alpha: 1.0)
            : UIColor(white: 0.15, alpha: 1.0)

        let image = UIImage(systemName: symbolName, withConfiguration: config)?
            .withTintColor(tintColor, renderingMode: .alwaysOriginal) ?? UIImage()

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: displaySize, height: displaySize))
        let rendered = renderer.image { ctx in
            // Draw a contrasting outline for white pieces on light squares
            if color == .white {
                let outline = image.withTintColor(UIColor(white: 0.3, alpha: 0.5), renderingMode: .alwaysOriginal)
                outline.draw(in: CGRect(x: 1, y: 1, width: displaySize, height: displaySize))
            }
            image.draw(in: CGRect(origin: .zero, size: CGSize(width: displaySize, height: displaySize)))
        }

        return SKTexture(image: rendered)
    }
}
