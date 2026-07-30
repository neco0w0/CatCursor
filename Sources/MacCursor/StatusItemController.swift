import Cocoa
import ServiceManagement

/// The menu bar item and its menu. This is the app's only user interface.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let settings = AppSettings.shared

    override init() {
        super.init()

        // The bundled artwork is a template image -- macOS renders it from alpha
        // alone, so it follows the menu bar's light or dark appearance.
        let icon = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: "cursorarrow.motionlines",
                       accessibilityDescription: "Cat Cursor")
        icon?.isTemplate = true
        icon?.size = NSSize(width: 15, height: 18)
        statusItem.button?.image = icon

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // Rebuilding on open keeps every check mark honest without observing state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(check("Cat Cursor Enabled",
                           action: #selector(toggleEnabled),
                           on: settings.isEnabled))
        menu.addItem(.separator())

        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for size in CursorSize.allCases {
            sizeMenu.addItem(check(size.title,
                                   action: #selector(selectSize(_:)),
                                   on: settings.size == size,
                                   represented: size.rawValue))
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        menu.addItem(check("Follow Cursor Shape",
                           action: #selector(toggleShapeSwitching),
                           on: settings.shapeSwitchingEnabled))
        menu.addItem(check("Paw Animation on Click",
                           action: #selector(toggleClickReaction),
                           on: settings.clickReactionEnabled))
        menu.addItem(check("Launch at Login",
                           action: #selector(toggleLaunchAtLogin),
                           on: SMAppService.mainApp.status == .enabled))

        menu.addItem(.separator())
        let calibrate = NSMenuItem(title: "Calibrate for This Mac…",
                                   action: #selector(calibrate), keyEquivalent: "")
        calibrate.target = self
        calibrate.toolTip = "Learn what this Mac's system cursors look like, so "
            + "the cat can follow their shapes. Needed on macOS versions other "
            + "than the one this build shipped with, or if you change the "
            + "system pointer size."
        menu.addItem(calibrate)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Cat Cursor",
                                action: #selector(quit), keyEquivalent: "q"))
        menu.items.last?.target = self
    }

    private func check(_ title: String, action: Selector, on: Bool,
                       represented: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = on ? .on : .off
        item.representedObject = represented
        return item
    }

    // MARK: - Actions

    @objc private func toggleEnabled() { settings.isEnabled.toggle() }

    @objc private func toggleClickReaction() { settings.clickReactionEnabled.toggle() }

    @objc private func toggleShapeSwitching() { settings.shapeSwitchingEnabled.toggle() }

    @objc private func selectSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let size = CursorSize(rawValue: raw) else { return }
        settings.size = size
    }

    /// Login items need a real, signed bundle; surface the reason rather than
    /// silently leaving the checkbox where it was.
    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change the login item"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    /// Handed in by the app delegate, which owns the overlay that has to be
    /// stood down while calibration takes the pointer.
    var onCalibrate: (() -> Void)?

    @objc private func calibrate() {
        let alert = NSAlert()
        alert.messageText = "Calibrate for this Mac?"
        alert.informativeText =
            "Cat Cursor will take over the pointer for about 20 seconds while it "
            + "learns what this Mac's system cursors look like. Please don't use "
            + "the mouse until it finishes.\n\nThis is what lets the cat follow "
            + "cursor shapes on your macOS version."
        alert.addButton(withTitle: "Calibrate")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        onCalibrate?()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
