import SwiftUI

/// UIKit owns the touch stream so WKWebView's scroll recognizers cannot steal a switcher drag.
@MainActor
struct FloatingSwitcherGestureView: UIViewRepresentable {
    let onTap: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTap: onTap,
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isAccessibilityElement = false

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.cancelsTouchesInView = true
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.require(toFail: pan)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onDragChanged = onDragChanged
        context.coordinator.onDragEnded = onDragEnded
    }

    @MainActor
    final class Coordinator: NSObject {
        var onTap: () -> Void
        var onDragChanged: (CGSize) -> Void
        var onDragEnded: (CGSize) -> Void

        init(
            onTap: @escaping () -> Void,
            onDragChanged: @escaping (CGSize) -> Void,
            onDragEnded: @escaping (CGSize) -> Void
        ) {
            self.onTap = onTap
            self.onDragChanged = onDragChanged
            self.onDragEnded = onDragEnded
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            onTap()
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: recognizer.view?.superview)
            let size = CGSize(width: translation.x, height: translation.y)
            switch recognizer.state {
            case .began, .changed:
                onDragChanged(size)
            case .ended, .cancelled, .failed:
                onDragEnded(size)
            default:
                break
            }
        }
    }
}
