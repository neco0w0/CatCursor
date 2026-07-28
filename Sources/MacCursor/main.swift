import Cocoa

let arguments = CommandLine.arguments

// Offscreen self-check, never reached in normal use.
if let flag = arguments.firstIndex(of: "--render-test") {
    let output = arguments.count > flag + 1 ? arguments[flag + 1] : "render-test.png"
    let segment = arguments.count > flag + 2 ? arguments[flag + 2] : "idle"
    let size = arguments.count > flag + 3
        ? CursorSize(rawValue: arguments[flag + 3]) ?? .medium
        : .medium
    exit(RenderTest.run(outputPath: output, segment: segment, size: size))
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
// Accessory: no Dock icon, never becomes the frontmost app.
application.setActivationPolicy(.accessory)
application.run()
