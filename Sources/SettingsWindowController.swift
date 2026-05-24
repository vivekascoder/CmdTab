import Cocoa

final class SettingsWindowController: NSWindowController {
    private var showBackgroundAppsCheckbox: NSButton!
    private var appearancePopup: NSPopUpButton!
    private var accessibilityStatusLabel: NSTextField!
    private var openAccessibilityButton: NSButton!

    var onSettingsChanged: (() -> Void)?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 280),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CmdTab Settings"
        window.titlebarAppearsTransparent = false
        self.init(window: window)
        buildUI()
        refreshAccessibilityStatus()
        window.center()
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        refreshAccessibilityStatus()
    }

    private func buildUI() {
        guard let window = window else { return }
        guard let contentView = window.contentView else { return }

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])

        let headerLabel = NSTextField(labelWithString: "Appearance")
        headerLabel.font = NSFont.boldSystemFont(ofSize: 13)
        headerLabel.textColor = NSColor.secondaryLabelColor
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerLabel)

        let showBgLabel = NSTextField(labelWithString: "Show background applications:")
        showBgLabel.font = NSFont.systemFont(ofSize: 13)
        showBgLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(showBgLabel)

        showBackgroundAppsCheckbox = NSButton(
            checkboxWithTitle: "",
            target: self,
            action: #selector(backgroundAppsToggled)
        )
        showBackgroundAppsCheckbox.translatesAutoresizingMaskIntoConstraints = false
        showBackgroundAppsCheckbox.state = AppSettings.shared.showBackgroundApps ? .on : .off
        container.addSubview(showBackgroundAppsCheckbox)

        let appearanceLabel = NSTextField(labelWithString: "Panel appearance:")
        appearanceLabel.font = NSFont.systemFont(ofSize: 13)
        appearanceLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(appearanceLabel)

        appearancePopup = NSPopUpButton()
        appearancePopup.addItems(withTitles: ["Auto", "Dark", "Light"])
        appearancePopup.translatesAutoresizingMaskIntoConstraints = false
        appearancePopup.target = self
        appearancePopup.action = #selector(appearanceChanged)

        switch AppSettings.shared.panelAppearance {
        case "dark": appearancePopup.selectItem(at: 1)
        case "light": appearancePopup.selectItem(at: 2)
        default: appearancePopup.selectItem(at: 0)
        }
        container.addSubview(appearancePopup)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)

        let permHeader = NSTextField(labelWithString: "Permissions")
        permHeader.font = NSFont.boldSystemFont(ofSize: 13)
        permHeader.textColor = NSColor.secondaryLabelColor
        permHeader.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(permHeader)

        accessibilityStatusLabel = NSTextField(labelWithString: "Checking…")
        accessibilityStatusLabel.font = NSFont.systemFont(ofSize: 12)
        accessibilityStatusLabel.textColor = NSColor.secondaryLabelColor
        accessibilityStatusLabel.lineBreakMode = .byWordWrapping
        accessibilityStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(accessibilityStatusLabel)

        openAccessibilityButton = NSButton(
            title: "Open Accessibility Settings",
            target: self,
            action: #selector(openAccessibilitySettings)
        )
        openAccessibilityButton.bezelStyle = .rounded
        openAccessibilityButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(openAccessibilityButton)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: container.topAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            showBgLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 14),
            showBgLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            showBackgroundAppsCheckbox.centerYAnchor.constraint(equalTo: showBgLabel.centerYAnchor),
            showBackgroundAppsCheckbox.leadingAnchor.constraint(equalTo: showBgLabel.trailingAnchor, constant: 6),

            appearanceLabel.topAnchor.constraint(equalTo: showBgLabel.bottomAnchor, constant: 14),
            appearanceLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            appearancePopup.centerYAnchor.constraint(equalTo: appearanceLabel.centerYAnchor),
            appearancePopup.leadingAnchor.constraint(equalTo: appearanceLabel.trailingAnchor, constant: 8),

            separator.topAnchor.constraint(equalTo: appearanceLabel.bottomAnchor, constant: 20),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            permHeader.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 14),
            permHeader.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            accessibilityStatusLabel.topAnchor.constraint(equalTo: permHeader.bottomAnchor, constant: 8),
            accessibilityStatusLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            accessibilityStatusLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            openAccessibilityButton.topAnchor.constraint(equalTo: accessibilityStatusLabel.bottomAnchor, constant: 12),
            openAccessibilityButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        ])
    }

    @objc private func backgroundAppsToggled() {
        AppSettings.shared.showBackgroundApps = (showBackgroundAppsCheckbox.state == .on)
        onSettingsChanged?()
    }

    @objc private func appearanceChanged() {
        let values = ["auto", "dark", "light"]
        let idx = appearancePopup.indexOfSelectedItem
        if idx >= 0, idx < values.count {
            AppSettings.shared.panelAppearance = values[idx]
        }
        onSettingsChanged?()
    }

    private func refreshAccessibilityStatus() {
        let trusted = AXIsProcessTrusted()
        if trusted {
            accessibilityStatusLabel.stringValue = "Accessibility access is granted. The right Command key is being monitored."
            accessibilityStatusLabel.textColor = NSColor.systemGreen
            openAccessibilityButton.isHidden = true
        } else {
            accessibilityStatusLabel.stringValue = "Accessibility access is not granted. CmdTab needs this permission to detect the right Command key."
            accessibilityStatusLabel.textColor = NSColor.systemRed
            openAccessibilityButton.isHidden = false
        }
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }
}
