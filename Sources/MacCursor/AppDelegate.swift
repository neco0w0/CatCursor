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

        statusItem = StatusItemController()

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
