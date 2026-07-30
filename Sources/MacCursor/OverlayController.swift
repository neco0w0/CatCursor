import Cocoa

/// A transparent, click-through window that spans every display.
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Hosts the cursor layer and keeps it glued to the pointer.
final class OverlayController {
    private let renderer: CursorRenderer
    private let tracker = MouseTracker()
    private var window: OverlayWindow?
    /// nil when calibration data is missing, in which case the app stays on the
    /// idle cat and never attempts shape switching.
    private var cursorTable: CursorTable?
    private var currentAction: CursorAction = .cat("arrow")
    private var tableMatchesThisSystem = false

    private(set) var isActive = false

    init(renderer: CursorRenderer, cursorTable: CursorTable?) {
        self.renderer = renderer
        self.cursorTable = cursorTable
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Lifecycle

    /// Order matters: the overlay has to be on screen and drawing before the
    /// real pointer is hidden, otherwise there is a window with no pointer at all.
    func activate() {
        guard !isActive else { return }

        let window = makeWindow()
        self.window = window
        guard let contentView = window.contentView else { return }

        contentView.layer?.addSublayer(renderer.hostLayer)
        renderer.showIdle()
        renderer.move(to: pointInWindow(NSEvent.mouseLocation, window: window))
        window.orderFrontRegardless()

        tracker.onMove = { [weak self] location in
            guard let self, let window = self.window else { return }
            self.renderer.move(to: self.pointInWindow(location, window: window))
        }
        tracker.onPressChange = { [weak self] pressed in
            guard let self, AppSettings.shared.clickReactionEnabled else { return }
            // Only the idle pointer gets the paw reaction. Playing it over a
            // text field or a resize handle would replace a cursor that is
            // telling the user something with one that is not.
            guard self.currentAction == .cat("arrow") else { return }
            pressed ? self.renderer.beginPress() : self.renderer.endPress()
        }
        tracker.onCursorChanged = { [weak self] in self?.systemCursorChanged() }
        tracker.start(driving: contentView)

        // Decide whether the reference data is usable *before* hiding anything,
        // while the real pointer is still the one on screen.
        recomputeTableValidity()

        SystemCursor.enableBackgroundControl()
        SystemCursor.hide()
        isActive = true
        systemCursorChanged()
    }

    func deactivate() {
        guard isActive else { return }
        SystemCursor.restore()
        tracker.stop()
        renderer.hostLayer.removeFromSuperlayer()
        window?.orderOut(nil)
        window = nil
        isActive = false
    }

    /// Swaps in freshly calibrated data. Validity is re-checked on the next
    /// activate, while the real pointer is still on screen.
    func reloadCursorTable(_ table: CursorTable?) {
        cursorTable = table
        tableMatchesThisSystem = false
    }

    func applySettings() {
        renderer.setSizeMultiplier(AppSettings.shared.size.multiplier)
        guard isActive else { return }
        if AppSettings.shared.shapeSwitchingEnabled {
            systemCursorChanged()
        } else {
            // Switching off means the cat is used everywhere again, so the real
            // pointer has to go back into hiding if a fallback had revealed it.
            apply(.cat("arrow"))
        }
    }

    // MARK: - Shape switching

    /// Decides what to draw after the system swapped its cursor.
    ///
    /// Anything unrecognised hands control back to the real pointer rather than
    /// guessing. Showing the wrong cat is worse than showing no cat: the drag
    /// badges in particular are the difference between copying an item and
    /// deleting it.
    private func systemCursorChanged() {
        guard isActive, AppSettings.shared.shapeSwitchingEnabled,
              tableMatchesThisSystem else { return }

        let action: CursorAction
        if let table = cursorTable,
           let reading = SystemCursorReader.read(),
           let name = table.match(reading),
           let matched = CursorPolicy.actions[name] {
            action = matched
        } else {
            action = .system
        }
        apply(action)
    }

    /// Whether the reference data describes *this* machine's cursors.
    ///
    /// The table is captured on one macOS version at one pointer size, and
    /// system cursor artwork changes between releases. On a machine it does not
    /// describe, nothing matches, every cursor falls back to the system one, and
    /// the app silently does nothing at all. Checking once up front lets it
    /// degrade to "cat everywhere" instead, which is at least the thing the user
    /// installed it for.
    private func recomputeTableValidity() {
        guard cursorTable != nil, let reading = SystemCursorReader.read() else {
            tableMatchesThisSystem = false
            return
        }
        tableMatchesThisSystem = cursorTable?.match(reading) != nil
        if !tableMatchesThisSystem {
            NSLog("Cat Cursor: cursor reference data does not match this system "
                  + "(macOS version or pointer size differs from calibration). "
                  + "Shape switching is off; showing the idle cat everywhere.")
        }
    }

    private static let verbose = CommandLine.arguments.contains("--verbose")

    private func apply(_ action: CursorAction) {
        guard action != currentAction else { return }
        currentAction = action
        if Self.verbose {
            switch action {
            case .cat(let name): print("cursor -> cat:\(name)")
            case .system: print("cursor -> system (unrecognised or deliberate fallback)")
            }
            fflush(stdout)
        }

        switch action {
        case .cat(let name):
            renderer.hostLayer.isHidden = false
            renderer.show(name)
            SystemCursor.hide()

        case .system:
            // Hand the pointer back first, and only stop drawing once it is
            // actually back. Doing it the other way round leaves a window with
            // no pointer at all, and if the restore fails that window never
            // closes -- which is the worst possible outcome for a cursor app.
            SystemCursor.restore()
            if SystemCursor.isVisible {
                renderer.hostLayer.isHidden = true
            } else {
                NSLog("Cat Cursor: could not hand the pointer back to the system; "
                      + "keeping the cat rather than showing nothing.")
                currentAction = .cat("arrow")
                renderer.hostLayer.isHidden = false
                renderer.show("arrow")
                SystemCursor.hide()
            }
        }
    }

    /// Reports the live state of the on-screen layer, used by `--diagnose` to
    /// confirm the cursor is actually attached and populated rather than an
    /// empty window sitting at the right level.
    func diagnosticSummary() -> String {
        guard let window else { return "overlay: inactive" }
        let layer = renderer.hostLayer
        let attached = layer.superlayer != nil
        let hasContents = layer.contents != nil
        let animating = layer.animationKeys()?.isEmpty == false
        return """
        overlay window : \(Int(window.frame.width))x\(Int(window.frame.height)) \
        at level \(window.level.rawValue), onScreen=\(window.isVisible)
        cursor layer   : attached=\(attached) contents=\(hasContents) \
        animating=\(animating) hidden=\(layer.isHidden)
        shape switching: enabled=\(AppSettings.shared.shapeSwitchingEnabled) \
        tableUsable=\(tableMatchesThisSystem) action=\(currentAction)
        layer bounds   : \(Int(layer.bounds.width))x\(Int(layer.bounds.height))pt \
        position=(\(Int(layer.position.x)), \(Int(layer.position.y)))
        pointer now    : \(NSEvent.mouseLocation)
        system cursor  : hidden=\(SystemCursor.isHiding) visible=\(SystemCursor.isVisible)
        """
    }

    // MARK: - Geometry

    /// Union of every screen, so a single window covers the whole desktop.
    private func desktopFrame() -> NSRect {
        NSScreen.screens.reduce(.zero) { $0.isEmpty ? $1.frame : $0.union($1.frame) }
    }

    private func pointInWindow(_ global: CGPoint, window: NSWindow) -> CGPoint {
        CGPoint(x: global.x - window.frame.origin.x,
                y: global.y - window.frame.origin.y)
    }

    private func makeWindow() -> OverlayWindow {
        let frame = desktopFrame()
        let window = OverlayWindow(contentRect: frame,
                                   styleMask: .borderless,
                                   backing: .buffered,
                                   defer: false)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true      // clicks pass through to apps below
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary,
                                     .fullScreenAuxiliary, .ignoresCycle]

        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear
        window.contentView = view
        return window
    }

    @objc private func screensChanged() {
        guard isActive, let window else { return }
        let frame = desktopFrame()
        window.setFrame(frame, display: false)
        window.contentView?.frame = NSRect(origin: .zero, size: frame.size)
    }
}
