import SwiftUI

/// Navigation controls for moving through game history.
struct NavigationBar: View {
    let viewModel: BoardViewModel
    var onFlip: (() -> Void)?

    var body: some View {
        HStack(spacing: 20) {
            // Go to start
            Button {
                viewModel.goToStart()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.body)
                    .frame(minWidth: 32, minHeight: 32)
            }
            .disabled(!viewModel.canGoBack)

            // Go back
            RepeatButton {
                viewModel.goBack()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 32, minHeight: 32)
            }
            .disabled(!viewModel.canGoBack)

            // Go forward
            RepeatButton {
                viewModel.goForward()
            } label: {
                Image(systemName: "chevron.forward")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 32, minHeight: 32)
            }
            .disabled(!viewModel.canGoForward)

            // Go to end
            Button {
                viewModel.goToEnd()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.body)
                    .frame(minWidth: 32, minHeight: 32)
            }
            .disabled(!viewModel.canGoForward)

            Spacer()

            // Flip board
            Button {
                onFlip?()
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.body)
                    .frame(minWidth: 32, minHeight: 32)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

/// A button that fires repeatedly when held down.
/// Starts at 2 actions/sec, accelerates to 5/sec after 1 second.
struct RepeatButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label

    @State private var timer: Timer?
    @State private var holdStart: Date?

    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    var body: some View {
        Button {
            action()
        } label: {
            label()
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.3)
                .onEnded { _ in
                    holdStart = Date()
                    startRepeating()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    stopRepeating()
                }
        )
    }

    private func startRepeating() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            action()
            // Accelerate after 1 second of holding
            if let start = holdStart, Date().timeIntervalSince(start) > 1.0 {
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                    action()
                }
            }
        }
    }

    private func stopRepeating() {
        timer?.invalidate()
        timer = nil
        holdStart = nil
    }
}
