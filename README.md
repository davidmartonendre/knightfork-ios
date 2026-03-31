# KnightFork

> **Work in Progress** — This app is under active development. Some features are incomplete or may not work as expected. All contributions are welcome!

## Features

- **Interactive Chess Board** — SpriteKit-rendered board with drag-drop and tap-tap move input, legal move indicators, last-move highlights, check indicators, promotion picker, and board flip
- **Play vs Stockfish** — Play against Stockfish 17 with configurable Elo (400–3200), time controls, and clocks
- **Deep Analysis** — Real-time multi-PV engine analysis with eval bar, best-move arrows, and interactive move list
- **Game Report** — Automated accuracy scoring with per-move annotations (brilliant, good, dubious, mistake, blunder), eval graph, and ACPL calculation using the Lichess win-probability formula
- **Opening Explorer** — Browse openings with move statistics from Lichess master/online databases and 7-piece endgame tablebase
- **Puzzles** — Tactical puzzles fetched from the Lichess puzzle API with difficulty and theme filtering
- **PGN Import/Export** — Import games from PGN files, export annotated PGN
- **Lichess & Chess.com Sync** — Import your game history by username
- **Games Library** — Browse, search, and manage your game collection with SwiftData persistence

## Requirements

- iOS 17.0+
- Xcode 16.0+
- Swift 5.9+

## Setup

1. Clone the repository
2. Open `KnightFork/KnightFork.xcodeproj` in Xcode
3. SPM dependencies (`chesskit-swift`, `chesskit-engine`) resolve automatically
4. Download NNUE weight files and add them to the Xcode project as bundle resources:
   - `nn-1111cefa1111.nnue` (~70 MB, Stockfish large net)
   - `nn-37f18f62d772.nnue` (~5 MB, Stockfish small net)
   - `192x15_network` (~5 MB, Lc0 weights)
5. Build and run on a simulator or device

## Architecture

```
UI Layer (SwiftUI + SpriteKit board)
        |
Game Logic (chesskit-swift)
        |
Engine Module (chesskit-engine — Stockfish 17, Lc0)
        |
Data Layer (SwiftData + file I/O)
```

**Key design decisions:**
- Board rendering uses SpriteKit (`SKScene`) wrapped in `UIViewRepresentable` for 60fps performance — all 64 squares baked into a single texture
- Single shared Stockfish engine instance (`SharedEngine` actor) — Stockfish uses global C state, so only one process can exist at a time
- Features swap the engine's response handler rather than creating/destroying engine instances

## Dependencies

| Package | Role |
|---|---|
| [chesskit-swift](https://github.com/chesskit-app/chesskit-swift) | Bitboard move generation, Board/Position/Game types, FEN/PGN/SAN parsing |
| [chesskit-engine](https://github.com/chesskit-app/chesskit-engine) | UCI protocol, bundled Stockfish 17 + Lc0 0.31.1 |

## Contributing

Contributions are welcome! The app is in active development and there's plenty to improve:

- Bug fixes and stability improvements
- UI/UX polish
- New features
- Performance optimization
- Accessibility improvements
- Tests

Please open an issue first to discuss significant changes.

## License

[GPL-3.0](LICENSE)
