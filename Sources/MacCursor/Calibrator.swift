import Cocoa

/// Captures what this Mac's system cursors look like, so recognition works on
/// whatever macOS version and pointer size the user actually has.
///
/// The reference data cannot be shipped once and reused everywhere: Apple
/// redraws the system cursors between releases, and the accessibility pointer
/// size changes them again. Data captured elsewhere matches nothing, which
/// turns shape switching off entirely.
///
/// Everything is captured through the same path recognition uses at runtime --
/// make the cursor current, then read it back from the window server. Capturing
/// from `NSCursor.image` is a different pipeline and, for the two most important
/// cursors, returns nothing at all.
final class Calibrator {
    static let fingerprintSide = 16

    struct Target {
        let name: String
        let cursor: NSCursor
    }

    enum Failure: Error, LocalizedError {
        case tooFewCaptured(Int)
        case couldNotWrite(String)

        var errorDescription: String? {
            switch self {
            case .tooFewCaptured(let count):
                return "Only \(count) cursors could be captured, which is not "
                     + "enough to recognise shapes reliably."
            case .couldNotWrite(let detail):
                return "Could not save the calibration data: \(detail)"
            }
        }
    }

    private var window: NSWindow?
    private var label: NSTextField?
    private var records: [(name: String, reading: SystemCursorReading, print: [UInt8])] = []
    private var targets: [Target] = []
    private var index = 0
    private var pointerOrigin = CGPoint.zero
    private var seedBeforeChange: Int32 = -1
    private var completion: ((Result<URL, Error>) -> Void)?

    // MARK: - Targets

    /// Public cursors, plus the private window-edge and corner ones.
    ///
    /// `NSCursor.resizeUpDown` and `.resizeLeftRight` are *not* the window-edge
    /// cursors -- they are the split-view divider ones. Dragging a window edge
    /// uses a separate private set at a different size, so both families have to
    /// be captured or half of all resizing goes unrecognised.
    private static func allTargets() -> [Target] {
        var list: [Target] = [
            Target(name: "arrow", cursor: .arrow),
            Target(name: "iBeam", cursor: .iBeam),
            Target(name: "iBeamVertical", cursor: .iBeamCursorForVerticalLayout),
            Target(name: "pointingHand", cursor: .pointingHand),
            Target(name: "crosshair", cursor: .crosshair),
            Target(name: "operationNotAllowed", cursor: .operationNotAllowed),
            Target(name: "resizeLeftRight", cursor: .resizeLeftRight),
            Target(name: "resizeLeft", cursor: .resizeLeft),
            Target(name: "resizeRight", cursor: .resizeRight),
            Target(name: "resizeUpDown", cursor: .resizeUpDown),
            Target(name: "resizeUp", cursor: .resizeUp),
            Target(name: "resizeDown", cursor: .resizeDown),
            Target(name: "openHand", cursor: .openHand),
            Target(name: "closedHand", cursor: .closedHand),
            Target(name: "dragCopy", cursor: .dragCopy),
            Target(name: "dragLink", cursor: .dragLink),
            Target(name: "contextualMenu", cursor: .contextualMenu),
            Target(name: "disappearingItem", cursor: .disappearingItem),
        ]

        for (selector, name) in [
            ("_windowResizeNorthWestSouthEastCursor", "resizeNWSE"),
            ("_windowResizeNorthEastSouthWestCursor", "resizeNESW"),
            ("_windowResizeNorthSouthCursor", "windowResizeNorthSouth"),
            ("_windowResizeNorthCursor", "windowResizeNorth"),
            ("_windowResizeSouthCursor", "windowResizeSouth"),
            ("_windowResizeEastWestCursor", "windowResizeEastWest"),
            ("_windowResizeEastCursor", "windowResizeEast"),
            ("_windowResizeWestCursor", "windowResizeWest"),
        ] {
            let sel = NSSelectorFromString(selector)
            guard NSCursor.responds(to: sel),
                  let cursor = NSCursor.perform(sel)?.takeUnretainedValue() as? NSCursor
            else { continue }
            list.append(Target(name: name, cursor: cursor))
        }
        return list
    }

    // MARK: - Run

    /// Roughly 20 seconds, during which the pointer is not the user's to move.
    func run(completion: @escaping (Result<URL, Error>) -> Void) {
        self.completion = completion
        self.targets = Self.allTargets()
        self.records = []
        self.index = 0

        presentWindow()
        pointerOrigin = NSEvent.mouseLocation

        // Give the window a moment to appear before taking the pointer.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.warpToWindowCentre()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.captureArrowFromDefaultState()
            }
        }
    }

    /// The arrow is whatever is on screen before anything has been set. On some
    /// macOS versions `NSCursor.arrow.set()` has no effect at all, so reading
    /// the untouched state is the only reliable way to get it.
    private func captureArrowFromDefaultState() {
        if let reading = SystemCursorReader.read() {
            record("arrow", reading)
        }
        index = 0
        captureNext()
    }

    private func captureNext() {
        guard index < targets.count else {
            captureIBeamViaFixture()
            return
        }
        let target = targets[index]
        // Already taken from the default state, and .set() may be a no-op for it.
        guard target.name != "arrow", target.name != "iBeam" else {
            index += 1
            captureNext()
            return
        }

        report("Reading \(target.name)… (\(index + 1)/\(targets.count))")

        // A sentinel first, so there is always a transition to observe. Without
        // it, capturing a cursor that already happens to be current produces no
        // seed change and looks like a failure.
        let sentinel: NSCursor = target.name == "crosshair" ? .pointingHand : .crosshair
        sentinel.set()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            guard let self else { return }
            self.seedBeforeChange = SystemCursorReader.seed
            target.cursor.set()
            self.awaitSeedChange(attempt: 0) { reading in
                if let reading { self.record(target.name, reading) }
                self.index += 1
                self.captureNext()
            }
        }
    }

    /// Polls on the run loop rather than sleeping, so the progress window keeps
    /// drawing while the pointer is held.
    private func awaitSeedChange(attempt: Int,
                                 done: @escaping (SystemCursorReading?) -> Void) {
        if SystemCursorReader.seed != seedBeforeChange {
            done(SystemCursorReader.read())
            return
        }
        guard attempt < 25 else { done(nil); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            self?.awaitSeedChange(attempt: attempt + 1, done: done)
        }
    }

    private func captureIBeamViaFixture() {
        report("Reading the text cursor…")
        guard let helper = Self.fixtureURL() else {
            finish()
            return
        }

        let process = Process()
        process.executableURL = helper
        process.arguments = ["4"]
        process.standardOutput = Pipe()
        do { try process.run() } catch {
            NSLog("Cat Cursor: calibration helper would not launch: \(error)")
            finish()
            return
        }

        // The helper warps onto its text view at ~0.6s and quits on its own.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            guard let self else { return }
            if let reading = SystemCursorReader.read(),
               let arrow = self.records.first(where: { $0.name == "arrow" }),
               Self.distance(SystemCursorReader.fingerprint(reading.image,
                                                            side: Self.fingerprintSide),
                             arrow.print) > 1 {
                self.record("iBeam", reading)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { self.finish() }
        }
    }

    private func finish() {
        NSCursor.arrow.set()
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        CGWarpMouseCursorPosition(CGPoint(x: pointerOrigin.x,
                                          y: screenHeight - pointerOrigin.y))
        dismissWindow()

        guard records.count >= 10 else {
            completion?(.failure(Failure.tooFewCaptured(records.count)))
            completion = nil
            return
        }
        do {
            let url = try write()
            completion?(.success(url))
        } catch {
            completion?(.failure(error))
        }
        completion = nil
    }

    // MARK: - Recording

    private func record(_ name: String, _ reading: SystemCursorReading) {
        guard !records.contains(where: { $0.name == name }) else { return }
        let print = SystemCursorReader.fingerprint(reading.image, side: Self.fingerprintSide)
        records.append((name: name, reading: reading, print: print))
    }

    private static func distance(_ a: [UInt8], _ b: [UInt8]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return .infinity }
        var total = 0
        for index in 0..<a.count { total += abs(Int(a[index]) - Int(b[index])) }
        return Double(total) / Double(a.count)
    }

    private func write() throws -> URL {
        let entries = records.map { record -> [String: Any] in
            [
                "name": record.name,
                "width": Int(record.reading.size.width),
                "height": Int(record.reading.size.height),
                "hotspotX": Int(record.reading.hotspot.x),
                "hotspotY": Int(record.reading.hotspot.y),
                "fingerprint": record.print.map { Int($0) },
            ]
        }
        let payload: [String: Any] = [
            "side": Self.fingerprintSide,
            "system": ProcessInfo.processInfo.operatingSystemVersionString,
            "cursors": entries,
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: payload,
                                                  options: [.sortedKeys])
            let url = CursorTable.userTableURL()
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            throw Failure.couldNotWrite(error.localizedDescription)
        }
    }

    private static func fixtureURL() -> URL? {
        var candidates: [URL] = []
        let contents = Bundle.main.bundleURL.appendingPathComponent("Contents")
        candidates.append(contents.appendingPathComponent("Helpers/CursorFixture"))
        // Development: sitting next to the executable in .build/release
        candidates.append(Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("CursorFixture"))
        let found = candidates.first {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }
        if found == nil { NSLog("Cat Cursor: calibration helper not found") }
        return found
    }

    // MARK: - Progress window

    private func presentWindow() {
        NSApp.setActivationPolicy(.regular)

        let frame = NSRect(x: 0, y: 0, width: 460, height: 150)
        let window = NSWindow(contentRect: frame, styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.title = "Calibrating Cat Cursor"
        window.center()

        let text = NSTextField(labelWithString:
            "Learning what this Mac's cursors look like.\n"
            + "Please don't touch the mouse for about 20 seconds.")
        text.alignment = .center
        text.frame = NSRect(x: 20, y: 80, width: 420, height: 46)
        text.maximumNumberOfLines = 2

        let status = NSTextField(labelWithString: "Starting…")
        status.alignment = .center
        status.textColor = .secondaryLabelColor
        status.frame = NSRect(x: 20, y: 40, width: 420, height: 20)

        window.contentView?.addSubview(text)
        window.contentView?.addSubview(status)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
        self.label = status
    }

    private func report(_ message: String) {
        label?.stringValue = message
    }

    private func dismissWindow() {
        window?.orderOut(nil)
        window = nil
        label = nil
        NSApp.setActivationPolicy(.accessory)
    }

    private func warpToWindowCentre() {
        guard let frame = window?.frame else { return }
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        CGWarpMouseCursorPosition(CGPoint(x: frame.midX, y: screenHeight - frame.midY))
    }
}
