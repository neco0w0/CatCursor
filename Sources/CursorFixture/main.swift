import Cocoa

// Calibration helper. Puts a real NSTextView under the pointer so AppKit sets
// the text I-beam exactly as any other app would, holds still long enough for
// the main app to read it, then puts the pointer back and exits.
//
// This exists as a separate process because it has to be: once anything in a
// process has called NSCursor.set(), AppKit treats the cursor as explicitly
// owned and stops letting cursor rects change it, so the app cannot produce a
// genuine I-beam for itself no matter how the calls are ordered.
//
// Usage: CursorFixture <seconds>

final class Fixture: NSObject, NSApplicationDelegate {
    private let lifetime: Double
    private var window: NSWindow!
    private var origin = CGPoint.zero

    init(lifetime: Double) {
        self.lifetime = lifetime
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        let frame = NSRect(x: 240, y: 240, width: 420, height: 260)
        window = NSWindow(contentRect: frame, styleMask: [.titled],
                          backing: .buffered, defer: false)
        window.title = "Calibrating text cursor…"

        let text = NSTextView(frame: NSRect(origin: .zero, size: frame.size))
        text.string = String(repeating: "calibrating the text cursor\n", count: 10)
        text.isEditable = false
        window.contentView = text

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        origin = NSEvent.mouseLocation

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Warping uses top-left origin; NSEvent.mouseLocation is bottom-left.
            CGWarpMouseCursorPosition(CGPoint(x: frame.midX,
                                              y: screenHeight - frame.midY))
            print("READY")
            fflush(stdout)
        }

        Timer.scheduledTimer(withTimeInterval: lifetime, repeats: false) { _ in
            CGWarpMouseCursorPosition(CGPoint(x: self.origin.x,
                                              y: screenHeight - self.origin.y))
            NSApp.terminate(nil)
        }
    }
}

let seconds = CommandLine.arguments.count > 1
    ? Double(CommandLine.arguments[1]) ?? 5 : 5
let app = NSApplication.shared
let fixture = Fixture(lifetime: seconds)
app.delegate = fixture
app.setActivationPolicy(.regular)
app.run()
