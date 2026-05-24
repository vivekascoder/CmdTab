import Cocoa

final class OverlayPanelController: NSObject {
    private var panel: NSPanel?
    private var stackView: NSStackView?
    private var appEntries: [NSRunningApplication] = []
    private var buttonRows: [NSButton] = []
    var isVisible: Bool { panel?.isVisible ?? false }

    private let numberKeyCodes: [Int64: Int] = [
        18: 0, 19: 1, 20: 2, 21: 3, 23: 4,
        22: 5, 26: 6, 28: 7, 25: 8, 29: 9,
        83: 0, 84: 1, 85: 2, 86: 3, 87: 4,
        88: 5, 89: 6, 91: 7, 92: 8, 82: 9,
    ]

    func index(for keyCode: Int64) -> Int? {
        numberKeyCodes[keyCode]
    }

    func selectApp(at index: Int, completion: @escaping (NSRunningApplication) -> Void) {
        guard index < appEntries.count else {
            hide()
            return
        }
        let app = appEntries[index]
        hide()
        completion(app)
    }

    func show() {
        buildAppList()
        guard !appEntries.isEmpty else { return }

        if panel == nil {
            createPanel()
        }
        if let panel = panel {
            AppSettings.shared.applyAppearance(to: panel)
        }
        refreshContent()
        positionPanel()

        panel?.alphaValue = 0
        panel?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel?.animator().alphaValue = 1
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func dismiss() {
        hide()
    }

    private func buildAppList() {
        let includeBackground = AppSettings.shared.showBackgroundApps

        let apps = NSWorkspace.shared.runningApplications.filter { app in
            let validBundle = app.bundleURL != nil
            let notSelf = app.processIdentifier != ProcessInfo.processInfo.processIdentifier
            let policyOK = includeBackground || app.activationPolicy == .regular
            return validBundle && notSelf && policyOK
        }

        appEntries = apps.sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        panel.isReleasedWhenClosed = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 100))
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 16
        contentView.layer?.masksToBounds = true
        contentView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.92).cgColor
        contentView.layer?.borderColor = NSColor.separatorColor.cgColor
        contentView.layer?.borderWidth = 0.5

        contentView.shadow = NSShadow()
        contentView.layer?.shadowColor = NSColor.black.cgColor
        contentView.layer?.shadowOpacity = 0.25
        contentView.layer?.shadowRadius = 20
        contentView.layer?.shadowOffset = NSSize(width: 0, height: -8)

        let titleLabel = NSTextField(labelWithString: "Switch to:")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 12)
        titleLabel.textColor = NSColor.secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.verticalScrollElasticity = .none

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 1
        stack.alignment = .leading
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        scrollView.documentView = stack
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -2),
        ])

        panel.contentView = contentView
        self.panel = panel
        self.stackView = stack
    }

    private func refreshContent() {
        guard let stack = stackView, let panel = panel else { return }

        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttonRows.removeAll()

        for (index, app) in appEntries.enumerated() {
            let displayNum: String
            if index < 9 {
                displayNum = "\(index + 1)"
            } else if index == 9 {
                displayNum = "0"
            } else {
                displayNum = "—"
            }

            let button = NSButton(frame: .zero)
            button.title = ""
            button.bezelStyle = .regularSquare
            button.isBordered = false
            button.translatesAutoresizingMaskIntoConstraints = false
            button.wantsLayer = true
            button.layer?.cornerRadius = 6
            button.tag = index
            button.target = self
            button.action = #selector(appButtonClicked(_:))

            let container = NSView()
            container.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(container)

            let numLabel = NSTextField(labelWithString: displayNum)
            numLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
            numLabel.textColor = NSColor.secondaryLabelColor
            numLabel.alignment = .right
            numLabel.translatesAutoresizingMaskIntoConstraints = false
            numLabel.setContentHuggingPriority(.required, for: .horizontal)
            container.addSubview(numLabel)

            let iconView = NSImageView()
            iconView.image = app.icon ?? NSImage()
            iconView.imageScaling = .scaleProportionallyDown
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.setContentHuggingPriority(.required, for: .horizontal)
            container.addSubview(iconView)

            let nameLabel = NSTextField(labelWithString: app.localizedName ?? "Unknown")
            nameLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
            nameLabel.textColor = NSColor.labelColor
            nameLabel.lineBreakMode = .byTruncatingTail
            nameLabel.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(nameLabel)

            NSLayoutConstraint.activate([
                numLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                numLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                numLabel.widthAnchor.constraint(equalToConstant: 22),

                iconView.leadingAnchor.constraint(equalTo: numLabel.trailingAnchor, constant: 8),
                iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 20),
                iconView.heightAnchor.constraint(equalToConstant: 20),

                nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
                nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
                nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

                container.topAnchor.constraint(equalTo: button.topAnchor, constant: 4),
                container.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -4),
                container.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 8),
                container.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -8),
            ])

            button.heightAnchor.constraint(equalToConstant: 34).isActive = true
            button.widthAnchor.constraint(equalToConstant: 324).isActive = true

            stack.addArrangedSubview(button)
            buttonRows.append(button)
        }

        let rowHeight: CGFloat = 36
        let headerHeight: CGFloat = 48
        let visibleRows = min(appEntries.count, 10)
        let contentHeight = CGFloat(visibleRows) * rowHeight + headerHeight
        let newHeight = max(contentHeight + 16, 80)

        var frame = panel.frame
        frame.size.height = newHeight
        panel.setFrame(frame, display: false)
        panel.layoutIfNeeded()
    }

    private func positionPanel() {
        guard let panel = panel else { return }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let screenFrame = screen.frame
        let panelFrame = panel.frame
        let x = screenFrame.midX - panelFrame.width / 2
        let y = screenFrame.midY - panelFrame.height / 2 + 60
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func appButtonClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index < appEntries.count else { return }
        let app = appEntries[index]
        hide()
        app.activate()
    }
}
