import AppKit
import SwiftUI

/// Helper to catch vertical trackpad scroll wheel events directly onto the teleprompter.
struct VerticalWheelScrollHelper: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> WheelCatcher {
        WheelCatcher(onScroll: onScroll)
    }

    func updateNSView(_ nsView: WheelCatcher, context: Context) {
        nsView.onScroll = onScroll
    }

    class WheelCatcher: NSView {
        var onScroll: (CGFloat) -> Void

        init(onScroll: @escaping (CGFloat) -> Void) {
            self.onScroll = onScroll
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func scrollWheel(with event: NSEvent) {
            if event.scrollingDeltaY != 0 {
                let delta = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY : -event.scrollingDeltaY
                onScroll(delta)
            } else {
                super.scrollWheel(with: event)
            }
        }
    }
}
