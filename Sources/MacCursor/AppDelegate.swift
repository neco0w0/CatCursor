import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var overlay: OverlayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Bail before touching the pointer: a second instance fighting the
        // first over the cursor is worse than simply not starting.
        guard SingleInstance.acquire() else {
            NSLog("Cat Cursor is already running; this instance is exiting.")
            NSApp.terminate(nil)
            return
        }

        // Headless calibration, for scripting and for troubleshooting a machine
        // where the menu is hard to reach.
        if CommandLine.arguments.contains("--calibrate") {
            runHeadlessCalibration()
            return
        }

        let statusItem = StatusItemController()
        statusItem.onCalibrate = { [weak self] in self?.calibrate() }
        self.statusItem = statusItem

        // Decoding ~300 PNG frames takes a few hundred milliseconds; keep it off
        // the main thread so the menu bar item appears immediately.
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try CursorAssets.loadAll() }
            DispatchQueue.main.async { self.assetsLoaded(result) }
        }
    }

    private func assetsLoaded(_ result: Result<[String: CursorAnimation], Error>) {
        switch result {
        case .failure(let error):
            report(error)
        case .success(let animations):
            do {
                let renderer = try CursorRenderer(animations: animations,
                                                  multiplier: AppSettings.shared.size.multiplier)
                let table = CursorTable.load()
                if table == nil {
                    NSLog("cursor_table.json missing or unreadable; "
                          + "shape switching disabled, idle cat only")
                }
                let overlay = OverlayController(renderer: renderer, cursorTable: table)
                self.overlay = overlay

                AppSettings.shared.onChange = { [weak self] in self?.applySettings() }
                applySettings()
                if CommandLine.arguments.contains("--diagnose") { runDiagnostics() }
            } catch {
                report(error)
            }
        }
    }

    private func applySettings() {
        guard let overlay else { return }
        overlay.applySettings()
        if AppSettings.shared.isEnabled {
            overlay.activate()
        } else {
            overlay.deactivate()
        }
    }

    private var calibrator: Calibrator?

    private func runHeadlessCalibration() {
        let calibrator = Calibrator()
        self.calibrator = calibrator
        calibrator.run { result in
            switch result {
            case .success(let url):
                print("calibration written to \(url.path)")
                if let table = CursorTable.load() {
                    print("loaded \(table.entries.count) cursors")
                    if let reading = SystemCursorReader.read() {
                        print("current cursor recognised as: "
                              + (table.match(reading) ?? "(no match)"))
                    }
                }
                NSApp.terminate(nil)
            case .failure(let error):
                FileHandle.standardError.write(
                    Data("calibration failed: \(error.localizedDescription)\n".utf8))
                exit(1)
            }
        }
    }

    /// Calibration needs the real pointer on screen and unobstructed, so the
    /// overlay stands down for the duration and is rebuilt with the new data.
    private func calibrate() {
        guard calibrator == nil else { return }
        overlay?.deactivate()

        let calibrator = Calibrator()
        self.calibrator = calibrator
        calibrator.run { [weak self] result in
            guard let self else { return }
            self.calibrator = nil

            let alert = NSAlert()
            switch result {
            case .success:
                self.overlay?.reloadCursorTable(CursorTable.load())
                alert.messageText = "Calibration finished"
                alert.informativeText = "Cat Cursor now recognises this Mac's "
                    + "cursors and will follow their shapes."
                alert.alertStyle = .informational
            case .failure(let error):
                alert.messageText = "Calibration did not finish"
                alert.informativeText = error.localizedDescription
                    + "\n\nCat Cursor will keep showing the idle cat everywhere."
                alert.alertStyle = .warning
            }

            // Restore the pointer before anything modal, so the user can click.
            self.applySettings()
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    /// Runs the overlay briefly, reports what is actually on screen, then quits.
    private func runDiagnostics() {
        Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
            print(self.overlay?.diagnosticSummary() ?? "overlay: missing")
            NSApp.terminate(nil)
        }
    }

    /// Never leave the pointer hidden because of an error path.
    private func report(_ error: Error) {
        overlay?.deactivate()
        SystemCursor.restore()

        let alert = NSAlert()
        alert.messageText = "Cat Cursor could not start"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.runModal()
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        overlay?.deactivate()
        SystemCursor.restore()
    }
}
