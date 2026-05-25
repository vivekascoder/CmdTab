import Cocoa

final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    private var showBackgroundAppsCheckbox: NSButton!
    private var appearancePopup: NSPopUpButton!
    private var layoutModePopup: NSPopUpButton!
    private var backgroundColorWell: NSColorWell!
    private var accessibilityStatusLabel: NSTextField!
    private var openAccessibilityButton: NSButton!
    private var ignoreButtons: [NSButton: String] = [:]
    private var shortcutFields: [NSTextField: String] = [:]

    var onSettingsChanged: (() -> Void)?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 430),
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

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabView)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
        ])

        tabView.addTabViewItem(tabItem(title: "General", view: buildGeneralTab()))
        tabView.addTabViewItem(tabItem(title: "Ignore List", view: buildIgnoreListTab()))
        tabView.addTabViewItem(tabItem(title: "Shortcuts", view: buildShortcutsTab()))
    }

    private func tabItem(title: String, view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: title)
        item.label = title
        item.view = view
        return item
    }

    private func buildGeneralTab() -> NSView {
        let container = NSView()
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

        let layoutModeLabel = NSTextField(labelWithString: "Overlay layout:")
        layoutModeLabel.font = NSFont.systemFont(ofSize: 13)
        layoutModeLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(layoutModeLabel)

        layoutModePopup = NSPopUpButton()
        layoutModePopup.addItems(withTitles: ["Blocks", "List"])
        layoutModePopup.translatesAutoresizingMaskIntoConstraints = false
        layoutModePopup.target = self
        layoutModePopup.action = #selector(layoutModeChanged)
        layoutModePopup.selectItem(at: AppSettings.shared.overlayLayoutMode == "list" ? 1 : 0)
        container.addSubview(layoutModePopup)

        let backgroundColorLabel = NSTextField(labelWithString: "Background color:")
        backgroundColorLabel.font = NSFont.systemFont(ofSize: 13)
        backgroundColorLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(backgroundColorLabel)

        backgroundColorWell = NSColorWell()
        backgroundColorWell.color = AppSettings.shared.overlayBackgroundColor
        backgroundColorWell.target = self
        backgroundColorWell.action = #selector(backgroundColorChanged)
        backgroundColorWell.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(backgroundColorWell)

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

            layoutModeLabel.topAnchor.constraint(equalTo: appearanceLabel.bottomAnchor, constant: 14),
            layoutModeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            layoutModePopup.centerYAnchor.constraint(equalTo: layoutModeLabel.centerYAnchor),
            layoutModePopup.leadingAnchor.constraint(equalTo: layoutModeLabel.trailingAnchor, constant: 8),

            backgroundColorLabel.topAnchor.constraint(equalTo: layoutModeLabel.bottomAnchor, constant: 14),
            backgroundColorLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            backgroundColorWell.centerYAnchor.constraint(equalTo: backgroundColorLabel.centerYAnchor),
            backgroundColorWell.leadingAnchor.constraint(equalTo: backgroundColorLabel.trailingAnchor, constant: 8),
            backgroundColorWell.widthAnchor.constraint(equalToConstant: 44),

            separator.topAnchor.constraint(equalTo: backgroundColorLabel.bottomAnchor, constant: 20),
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

        return paddedScrollView(containing: container)
    }

    private func buildIgnoreListTab() -> NSView {
        ignoreButtons.removeAll()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false

        let apps = settingsApplications()
        for app in apps {
            guard let bundleID = app.bundleIdentifier else { continue }

            let checkbox = NSButton(
                checkboxWithTitle: app.localizedName ?? bundleID,
                target: self,
                action: #selector(ignoreAppToggled(_:))
            )
            checkbox.state = AppSettings.shared.ignoredBundleIDs.contains(bundleID) ? .on : .off
            checkbox.font = NSFont.systemFont(ofSize: 13)
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            ignoreButtons[checkbox] = bundleID

            let row = appRow(app: app, trailingView: checkbox)
            stack.addArrangedSubview(row)
        }

        if stack.arrangedSubviews.isEmpty {
            stack.addArrangedSubview(emptyLabel("No running applications available."))
        }

        return paddedScrollView(containing: stack)
    }

    private func buildShortcutsTab() -> NSView {
        shortcutFields.removeAll()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false

        let apps = settingsApplications()
        for app in apps {
            guard let bundleID = app.bundleIdentifier else { continue }

            let field = NSTextField()
            field.placeholderString = "key"
            field.stringValue = AppSettings.shared.appShortcuts[bundleID] ?? ""
            field.maximumNumberOfLines = 1
            field.alignment = .center
            field.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
            field.delegate = self
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: 54).isActive = true
            shortcutFields[field] = bundleID

            let row = appRow(app: app, trailingView: field)
            stack.addArrangedSubview(row)
        }

        if stack.arrangedSubviews.isEmpty {
            stack.addArrangedSubview(emptyLabel("No running applications available."))
        }

        return paddedScrollView(containing: stack)
    }

    private func paddedScrollView(containing documentView: NSView) -> NSView {
        let outer = NSView()
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(documentView)
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = content
        outer.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: outer.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: outer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: outer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: outer.bottomAnchor),

            content.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            documentView.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            documentView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            documentView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            documentView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),
        ])

        return outer
    }

    private func appRow(app: NSRunningApplication, trailingView: NSView) -> NSView {
        let row = NSView()
        row.wantsLayer = true
        row.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55).cgColor
        row.layer?.cornerRadius = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = app.icon ?? NSImage()
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(iconView)

        let nameLabel = NSTextField(labelWithString: app.localizedName ?? app.bundleIdentifier ?? "Unknown")
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(nameLabel)

        trailingView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(trailingView)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 48),

            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            nameLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            trailingView.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 12),
            trailingView.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            trailingView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])

        return row
    }

    private func emptyLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.textColor = .secondaryLabelColor
        label.font = NSFont.systemFont(ofSize: 13)
        return label
    }

    private func settingsApplications() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { app in
                app.bundleURL != nil &&
                app.bundleIdentifier != nil &&
                app.processIdentifier != ProcessInfo.processInfo.processIdentifier
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
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

    @objc private func layoutModeChanged() {
        AppSettings.shared.overlayLayoutMode = layoutModePopup.indexOfSelectedItem == 1 ? "list" : "block"
        onSettingsChanged?()
    }

    @objc private func backgroundColorChanged() {
        AppSettings.shared.overlayBackgroundColor = backgroundColorWell.color
        onSettingsChanged?()
    }

    @objc private func ignoreAppToggled(_ sender: NSButton) {
        guard let bundleID = ignoreButtons[sender] else { return }
        AppSettings.shared.setIgnored(sender.state == .on, for: bundleID)
        onSettingsChanged?()
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField,
              let bundleID = shortcutFields[field] else { return }

        let normalized = field.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .first
            .map(String.init) ?? ""
        field.stringValue = normalized
        AppSettings.shared.setShortcut(normalized.isEmpty ? nil : normalized, for: bundleID)
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
