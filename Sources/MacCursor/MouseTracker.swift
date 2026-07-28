import Cocoa
import QuartzCore

/// Samples the pointer once per display refresh.
///
/// Polling `NSEvent.mouseLocation` rather than installing a global event
/// monitor is what keeps the app permission-free: no Accessibility prompt, no
/// Input Monitoring prompt. The cost is one cheap read per frame.
final class MouseTracker {
    private var displayLink: CADisplayLink?
    private var wasPressed = false
    private var ticksSinceCursorCheck = 0

    /// Roughly once a second at 60Hz.
    private static let cursorCheckInterval = 60

    var onMove: ((CGPoint) -> Void)?
    var onPressChange: ((Bool) -> Void)?
    /// Fires when the system swaps the cursor, e.g. moving onto a text field.
    var onCursorChanged: (() -> Void)?

    private var lastCursorSeed: Int32 = -1

    var isRunning: Bool { displayLink != nil }

    func start(driving view: NSView) {
        guard displayLink == nil else { return }
        let link = view.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        wasPressed = false
    }

    @objc private func tick() {
        onMove?(NSEvent.mouseLocation)

        let pressed = NSEvent.pressedMouseButtons & 0x1 != 0
        if pressed != wasPressed {
            wasPressed = pressed
            onPressChange?(pressed)
        }

        // Reading the seed every frame is a single integer; the cursor bitmap
        // is only fetched when it actually changes.
        let seed = SystemCursorReader.seed
        if seed != lastCursorSeed {
            lastCursorSeed = seed
            onCursorChanged?()
        }

        ticksSinceCursorCheck += 1
        if ticksSinceCursorCheck >= Self.cursorCheckInterval {
            ticksSinceCursorCheck = 0
            SystemCursor.reassertIfNeeded()
        }
    }
}
