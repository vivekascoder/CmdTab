import Cocoa

final class SettingsWindowController: NSWindowController, NSTextFieldDelegate, NSSearchFieldDelegate {
    private var showBackgroundAppsCheckbox: NSButton!
    private var appearancePopup: NSPopUpButton!
    private var layoutModePopup: NSPopUpButton!
    private var backgroundColorWell: NSColorWell!
    private var accessibilityStatusLabel: NSTextField!
    private var openAccessibilityButton: NSButton!
    private var ignoreButtons: [NSButton: String] = [:]
    private var shortcutFields: [NSTextField: String] = [:]
    private var ignoreSearchField: NSSearchField!
    private var shortcutsSearchField: NSSearchField!
    private var ignoreBackgroundAppsCheckbox: NSButton!
    private var shortcutsBackgroundAppsCheckbox: NSButton!
    private var ignoreListStack: NSStackView!
    private var shortcutsListStack: NSStackView!

    var onSettingsChanged: (() -> Void)?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 430),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CmdTab Settings"
        window.minSize = NSSize(width: 500, height: 360)
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
        tabView.addTabViewItem(tabItem(title: "About", view: buildAboutTab()))
    }

    private func tabItem(title: String, view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: title)
        item.label = title
        item.view = view
        return item
    }

    private func buildGeneralTab() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 14
        stack.alignment = .width

        let headerLabel = NSTextField(labelWithString: "Appearance")
        headerLabel.font = NSFont.boldSystemFont(ofSize: 13)
        headerLabel.textColor = NSColor.secondaryLabelColor
        stack.addArrangedSubview(headerLabel)

        showBackgroundAppsCheckbox = NSButton(
            checkboxWithTitle: "",
            target: self,
            action: #selector(backgroundAppsToggled)
        )
        showBackgroundAppsCheckbox.state = AppSettings.shared.showBackgroundApps ? .on : .off
        let backgroundAppsHelp = NSButton(title: "", target: nil, action: nil)
        backgroundAppsHelp.bezelStyle = .helpButton
        backgroundAppsHelp.toolTip = "Include background applications in the overlay."
        stack.addArrangedSubview(settingCard(
            title: "Show background apps",
            detail: nil,
            control: trailingControls(showBackgroundAppsCheckbox, backgroundAppsHelp)
        ))

        appearancePopup = NSPopUpButton()
        appearancePopup.addItems(withTitles: ["Auto", "Dark", "Light"])
        appearancePopup.target = self
        appearancePopup.action = #selector(appearanceChanged)

        switch AppSettings.shared.panelAppearance {
        case "dark": appearancePopup.selectItem(at: 1)
        case "light": appearancePopup.selectItem(at: 2)
        default: appearancePopup.selectItem(at: 0)
        }
        stack.addArrangedSubview(settingCard(title: "Panel appearance", detail: "Choose how the overlay follows system appearance.", control: appearancePopup))

        layoutModePopup = NSPopUpButton()
        layoutModePopup.addItems(withTitles: ["Blocks", "List"])
        layoutModePopup.target = self
        layoutModePopup.action = #selector(layoutModeChanged)
        layoutModePopup.selectItem(at: AppSettings.shared.overlayLayoutMode == "list" ? 1 : 0)
        stack.addArrangedSubview(settingCard(title: "Overlay layout", detail: "Switch between block grid and compact list modes.", control: layoutModePopup))

        backgroundColorWell = NSColorWell()
        backgroundColorWell.color = AppSettings.shared.overlayBackgroundColor
        backgroundColorWell.target = self
        backgroundColorWell.action = #selector(backgroundColorChanged)
        backgroundColorWell.widthAnchor.constraint(equalToConstant: 44).isActive = true
        stack.addArrangedSubview(settingCard(title: "Background color", detail: "Tint used behind the overlay content.", control: backgroundColorWell))

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(separator)

        let permHeader = NSTextField(labelWithString: "Permissions")
        permHeader.font = NSFont.boldSystemFont(ofSize: 13)
        permHeader.textColor = NSColor.secondaryLabelColor
        stack.addArrangedSubview(permHeader)

        accessibilityStatusLabel = NSTextField(labelWithString: "Checking…")
        accessibilityStatusLabel.font = NSFont.systemFont(ofSize: 12)
        accessibilityStatusLabel.textColor = NSColor.secondaryLabelColor
        accessibilityStatusLabel.lineBreakMode = .byWordWrapping
        accessibilityStatusLabel.maximumNumberOfLines = 0
        stack.addArrangedSubview(settingCard(title: "Accessibility", detail: "Required to monitor the right Command key.", control: accessibilityStatusLabel))

        openAccessibilityButton = NSButton(
            title: "Open Accessibility Settings",
            target: self,
            action: #selector(openAccessibilitySettings)
        )
        openAccessibilityButton.bezelStyle = .rounded
        stack.addArrangedSubview(openAccessibilityButton)

        return paddedScrollView(containing: stack)
    }

    private func buildAboutTab() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .width

        let title = NSTextField(labelWithString: "CmdTab")
        title.font = NSFont.boldSystemFont(ofSize: 18)
        stack.addArrangedSubview(title)

        let description = NSTextField(labelWithString: "A lightweight macOS app switcher for the right Command key.")
        description.textColor = .secondaryLabelColor
        description.font = NSFont.systemFont(ofSize: 13)
        stack.addArrangedSubview(description)

        stack.addArrangedSubview(linkCard(title: "Website", detail: "vivek.ink", url: "https://vivek.ink"))
        stack.addArrangedSubview(linkCard(title: "Twitter", detail: "0xstatemachine", url: "https://twitter.com/0xstatemachine"))

        return paddedScrollView(containing: stack)
    }

    private func buildIgnoreListTab() -> NSView {
        let stack = appListContainer(
            searchField: &ignoreSearchField,
            backgroundAppsCheckbox: &ignoreBackgroundAppsCheckbox,
            listStack: &ignoreListStack,
            searchAction: #selector(ignoreSearchChanged),
            backgroundAction: #selector(ignoreBackgroundAppsToggled)
        )
        reloadIgnoreList()
        return paddedScrollView(containing: stack)
    }

    private func buildShortcutsTab() -> NSView {
        let stack = appListContainer(
            searchField: &shortcutsSearchField,
            backgroundAppsCheckbox: &shortcutsBackgroundAppsCheckbox,
            listStack: &shortcutsListStack,
            searchAction: #selector(shortcutsSearchChanged),
            backgroundAction: #selector(shortcutsBackgroundAppsToggled)
        )
        reloadShortcutsList()
        return paddedScrollView(containing: stack)
    }

    private func appListContainer(
        searchField: inout NSSearchField!,
        backgroundAppsCheckbox: inout NSButton!,
        listStack: inout NSStackView!,
        searchAction: Selector,
        backgroundAction: Selector
    ) -> NSStackView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 12
        container.alignment = .width

        searchField = NSSearchField()
        searchField.placeholderString = "Search applications"
        searchField.target = self
        searchField.action = searchAction
        searchField.delegate = self
        container.addArrangedSubview(searchField)

        backgroundAppsCheckbox = NSButton(
            checkboxWithTitle: "Show background applications",
            target: self,
            action: backgroundAction
        )
        container.addArrangedSubview(backgroundAppsCheckbox)

        listStack = NSStackView()
        listStack.orientation = .vertical
        listStack.spacing = 8
        listStack.alignment = .width
        container.addArrangedSubview(listStack)

        return container
    }

    private func reloadIgnoreList() {
        guard let ignoreListStack else { return }
        ignoreButtons.removeAll()
        ignoreListStack.arrangedSubviews.forEach { view in
            ignoreListStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let apps = settingsApplications(
            includeBackground: ignoreBackgroundAppsCheckbox?.state == .on,
            query: ignoreSearchField?.stringValue ?? ""
        )
        for app in apps {
            guard let bundleID = app.bundleIdentifier else { continue }

            let checkbox = NSButton(
                checkboxWithTitle: "",
                target: self,
                action: #selector(ignoreAppToggled(_:))
            )
            checkbox.state = AppSettings.shared.ignoredBundleIDs.contains(bundleID) ? .on : .off
            checkbox.font = NSFont.systemFont(ofSize: 13)
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            ignoreButtons[checkbox] = bundleID

            let row = appRow(app: app, trailingView: checkbox)
            ignoreListStack.addArrangedSubview(row)
        }

        if ignoreListStack.arrangedSubviews.isEmpty {
            ignoreListStack.addArrangedSubview(emptyLabel("No matching applications."))
        }
    }

    private func reloadShortcutsList() {
        guard let shortcutsListStack else { return }
        shortcutFields.removeAll()
        shortcutsListStack.arrangedSubviews.forEach { view in
            shortcutsListStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let apps = settingsApplications(
            includeBackground: shortcutsBackgroundAppsCheckbox?.state == .on,
            query: shortcutsSearchField?.stringValue ?? ""
        )
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
            shortcutsListStack.addArrangedSubview(row)
        }

        if shortcutsListStack.arrangedSubviews.isEmpty {
            shortcutsListStack.addArrangedSubview(emptyLabel("No matching applications."))
        }
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

    private func settingCard(title: String, detail: String?, control: NSView) -> NSView {
        let row = baseCardRow()

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(titleLabel)

        control.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(control)

        var constraints: [NSLayoutConstraint] = [
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),

            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),

            control.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            control.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ]

        if let detail, !detail.isEmpty {
            let detailLabel = NSTextField(labelWithString: detail)
            detailLabel.font = NSFont.systemFont(ofSize: 12)
            detailLabel.textColor = .secondaryLabelColor
            detailLabel.lineBreakMode = .byTruncatingTail
            detailLabel.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(detailLabel)

            constraints.append(contentsOf: [
                titleLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 10),
                detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
                detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -10),
                control.leadingAnchor.constraint(greaterThanOrEqualTo: detailLabel.trailingAnchor, constant: 12),
            ])
        } else {
            constraints.append(contentsOf: [
                titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                control.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
            ])
        }

        NSLayoutConstraint.activate(constraints)

        return row
    }

    private func trailingControls(_ views: NSView...) -> NSView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }

    private func linkCard(title: String, detail: String, url: String) -> NSView {
        let button = NSButton(title: detail, target: self, action: #selector(openAboutLink(_:)))
        button.bezelStyle = .inline
        button.tag = url == "https://vivek.ink" ? 1 : 2
        return settingCard(title: title, detail: url, control: button)
    }

    private func baseCardRow() -> NSView {
        let row = NSView()
        row.wantsLayer = true
        row.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55).cgColor
        row.layer?.cornerRadius = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func appRow(app: NSRunningApplication, trailingView: NSView) -> NSView {
        let row = baseCardRow()

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

    private func settingsApplications(includeBackground: Bool, query: String) -> [NSRunningApplication] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return NSWorkspace.shared.runningApplications
            .filter { app in
                guard app.bundleURL != nil,
                      app.bundleIdentifier != nil,
                      app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
                    return false
                }

                if !includeBackground && app.activationPolicy != .regular {
                    return false
                }

                guard !normalizedQuery.isEmpty else { return true }
                let name = app.localizedName?.lowercased() ?? ""
                let bundleID = app.bundleIdentifier?.lowercased() ?? ""
                return name.contains(normalizedQuery) || bundleID.contains(normalizedQuery)
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

    @objc private func ignoreSearchChanged() {
        reloadIgnoreList()
    }

    @objc private func shortcutsSearchChanged() {
        reloadShortcutsList()
    }

    @objc private func ignoreBackgroundAppsToggled() {
        reloadIgnoreList()
    }

    @objc private func shortcutsBackgroundAppsToggled() {
        reloadShortcutsList()
    }

    func controlTextDidChange(_ obj: Notification) {
        if obj.object as? NSSearchField === ignoreSearchField {
            reloadIgnoreList()
            return
        }

        if obj.object as? NSSearchField === shortcutsSearchField {
            reloadShortcutsList()
            return
        }

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

    @objc private func openAboutLink(_ sender: NSButton) {
        let urlString = sender.tag == 1 ? "https://vivek.ink" : "https://twitter.com/0xstatemachine"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
