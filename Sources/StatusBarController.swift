import Cocoa

final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var settingsWindowController: SettingsWindowController?

    var onTestOverlay: (() -> Void)?
    var onSettingsChanged: (() -> Void)?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = createStatusIcon(active: false)
        statusItem.button?.toolTip = "CmdTab"

        let menu = NSMenu()

        let stateItem = NSMenuItem(
            title: "⌛ Checking…",
            action: nil,
            keyEquivalent: ""
        )
        stateItem.tag = 100
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        let testItem = NSMenuItem(
            title: "Test Overlay",
            action: #selector(testOverlay),
            keyEquivalent: ""
        )
        testItem.target = self
        menu.addItem(testItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func updateState(monitoringActive: Bool) {
        guard let stateItem = statusItem?.menu?.item(withTag: 100) else { return }

        if monitoringActive {
            stateItem.title = "✓ Monitoring Active"
            stateItem.action = nil
            stateItem.isEnabled = false
            statusItem.button?.image = createStatusIcon(active: true)
        } else {
            stateItem.title = "✗ Accessibility Required"
            stateItem.action = #selector(openAccessibility)
            stateItem.target = self
            stateItem.isEnabled = true
            statusItem.button?.image = createStatusIcon(active: false)
        }
    }

    @objc private func testOverlay() {
        onTestOverlay?()
    }

    @objc private func openAccessibility() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
            settingsWindowController?.onSettingsChanged = { [weak self] in
                self?.onSettingsChanged?()
            }
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func createStatusIcon(active: Bool = false) -> NSImage {
        let size = NSSize(width: 22, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .bold),
                .foregroundColor: NSColor.controlTextColor,
            ]
            let text = NSAttributedString(string: "⌘", attributes: attrs)
            let textSize = text.size()
            let x = (rect.width - textSize.width) / 2
            let y = (rect.height - textSize.height) / 2
            text.draw(at: NSPoint(x: x, y: y))

            if active {
                NSColor.systemGreen.setFill()
            } else {
                NSColor.systemGray.setFill()
            }
            let dot = NSBezierPath(ovalIn: NSRect(x: rect.maxX - 7, y: rect.maxY - 7, width: 5, height: 5))
            dot.fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
