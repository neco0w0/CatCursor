import Cocoa
import ServiceManagement

/// The menu bar item and its menu. This is the app's only user interface.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let settings = AppSettings.shared

    override init() {
        super.init()

        statusItem.button?.image = NSImage(
            systemSymbolName: "cursorarrow.motionlines",
            accessibilityDescription: "Cat Cursor")
        statusItem.button?.image?.isTemplate = true

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

    @objc private func quit() { NSApp.terminate(nil) }
}
