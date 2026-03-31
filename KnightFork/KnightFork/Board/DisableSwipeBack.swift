import SwiftUI
import UIKit

/// Disables the iOS interactive pop (swipe-back) gesture on a view.
/// Use on screens with a chess board where left swipe conflicts.
extension View {
    func disableSwipeBack() -> some View {
        self.background(SwipeBackDisablerView())
    }
}

/// Uses a UIView inserted into the hierarchy to reliably find and disable
/// the navigation controller's interactive pop gesture recognizer.
private struct SwipeBackDisablerView: UIViewRepresentable {
    func makeUIView(context: Context) -> SwipeBackDisablerUIView {
        SwipeBackDisablerUIView()
    }
    func updateUIView(_ uiView: SwipeBackDisablerUIView, context: Context) {}
}

private class SwipeBackDisablerUIView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            self?.findAndDisableSwipeBack()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        findAndDisableSwipeBack()
    }

    private func findAndDisableSwipeBack() {
        // Walk up the responder chain to find the navigation controller
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let nav = next as? UINavigationController {
                nav.interactivePopGestureRecognizer?.isEnabled = false
                return
            }
            responder = next
        }
    }

    deinit {
        // Re-enable when this view is removed
        var responder: UIResponder? = superview
        while let next = responder?.next {
            if let nav = next as? UINavigationController {
                nav.interactivePopGestureRecognizer?.isEnabled = true
                return
            }
            responder = next
        }
    }
}
