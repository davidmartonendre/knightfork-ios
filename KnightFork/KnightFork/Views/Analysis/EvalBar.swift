import SwiftUI
import ChessKit

/// Vertical eval bar showing engine evaluation as white/black fill proportion.
struct EvalBar: View {
    let score: EngineScore?
    let depth: Int
    var sideToMove: Piece.Color = .white

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Dark (black's side) fills the whole bar
                Rectangle()
                    .fill(Color.black)

                // White fill grows from bottom with white's advantage
                Rectangle()
                    .fill(Color.white)
                    .frame(height: geo.size.height * fillFraction)
                    .animation(.easeInOut(duration: 0.2), value: fillFraction)
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay {
                // Eval text — positioned based on who's winning
                VStack {
                    if fillFraction < 0.5 {
                        // Black winning — show at top
                        Text(evalText)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.top, 4)
                        Spacer()
                    } else {
                        // White winning — show at bottom
                        Spacer()
                        Text(evalText)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.bottom, 4)
                    }
                }
            }
        }
        .frame(width: 28)
    }

    private var normalizedScore: EngineScore? {
        guard let score else { return nil }
        if sideToMove == .white { return score }
        switch score {
        case .cp(let cp): return .cp(-cp)
        case .mate(let n): return .mate(-n)
        }
    }

    private var fillFraction: Double {
        guard let s = normalizedScore else { return 0.5 }
        return s.evalBarFraction
    }

    private var evalText: String {
        guard let s = normalizedScore else { return "" }
        switch s {
        case .cp(let cp):
            let pawns = abs(cp) / 100.0
            if pawns < 0.1 { return "0.0" }
            return String(format: "%.1f", pawns)
        case .mate(let n):
            return "M\(abs(n))"
        }
    }
}
