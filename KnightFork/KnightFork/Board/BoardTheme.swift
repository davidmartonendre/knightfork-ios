import UIKit

/// Defines the visual appearance of the chess board squares and overlays.
struct BoardTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let lightSquare: UIColor
    let darkSquare: UIColor
    let lastMoveHighlight: UIColor
    let legalMoveDot: UIColor
    let selectedSquare: UIColor
    let checkIndicator: UIColor
    let coordinateFont: UIColor

    static let classicGreen = BoardTheme(
        id: "classicGreen",
        name: "Classic Green",
        lightSquare: UIColor(red: 0.93, green: 0.93, blue: 0.82, alpha: 1),
        darkSquare: UIColor(red: 0.46, green: 0.59, blue: 0.34, alpha: 1),
        lastMoveHighlight: UIColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 0.4),
        legalMoveDot: UIColor(red: 0, green: 0, blue: 0, alpha: 0.2),
        selectedSquare: UIColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 0.5),
        checkIndicator: UIColor.red.withAlphaComponent(0.6),
        coordinateFont: UIColor(white: 0.3, alpha: 0.8)
    )

    static let blueWhite = BoardTheme(
        id: "blueWhite",
        name: "Blue / White",
        lightSquare: UIColor(red: 0.92, green: 0.93, blue: 0.97, alpha: 1),
        darkSquare: UIColor(red: 0.45, green: 0.53, blue: 0.68, alpha: 1),
        lastMoveHighlight: UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 0.4),
        legalMoveDot: UIColor(red: 0, green: 0, blue: 0, alpha: 0.2),
        selectedSquare: UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 0.5),
        checkIndicator: UIColor.red.withAlphaComponent(0.6),
        coordinateFont: UIColor(white: 0.3, alpha: 0.8)
    )

    static let brownTan = BoardTheme(
        id: "brownTan",
        name: "Brown / Tan",
        lightSquare: UIColor(red: 0.94, green: 0.85, blue: 0.71, alpha: 1),
        darkSquare: UIColor(red: 0.71, green: 0.53, blue: 0.39, alpha: 1),
        lastMoveHighlight: UIColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 0.4),
        legalMoveDot: UIColor(red: 0, green: 0, blue: 0, alpha: 0.2),
        selectedSquare: UIColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 0.5),
        checkIndicator: UIColor.red.withAlphaComponent(0.6),
        coordinateFont: UIColor(white: 0.3, alpha: 0.8)
    )

    static let highContrast = BoardTheme(
        id: "highContrast",
        name: "High Contrast",
        lightSquare: .white,
        darkSquare: UIColor(white: 0.25, alpha: 1),
        lastMoveHighlight: UIColor.systemYellow.withAlphaComponent(0.5),
        legalMoveDot: UIColor.systemBlue.withAlphaComponent(0.4),
        selectedSquare: UIColor.systemYellow.withAlphaComponent(0.6),
        checkIndicator: UIColor.systemRed.withAlphaComponent(0.7),
        coordinateFont: UIColor(white: 0.5, alpha: 0.9)
    )

    static let allThemes: [BoardTheme] = [.classicGreen, .blueWhite, .brownTan, .highContrast]
}
