import Cocoa

private let blockW: CGFloat = 112
private let blockH: CGFloat = 134
private let blockGap: CGFloat = 12
private let maxCols = 4
private let listRowH: CGFloat = 58
private let listW: CGFloat = 420
private let overlayCornerRadius: CGFloat = 38

private final class RoundedVisualEffectView: NSVisualEffectView {
    override func layout() {
        super.layout()
        maskImage = roundedMaskImage(size: bounds.size, radius: overlayCornerRadius)
    }

    private func roundedMaskImage(size: NSSize, radius: CGFloat) -> NSImage? {
        guard size.width > 0, size.height > 0 else { return nil }

        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: radius, yRadius: radius).fill()
        image.unlockFocus()

        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

private final class OverlayListRowButton: NSButton {
    private var isHovered = false
    private var isPressedRow = false

    override var isHighlighted: Bool {
        didSet {
            isPressedRow = isHighlighted
            updateBackground()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateBackground()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressedRow = false
        updateBackground()
    }

    private func updateBackground() {
        wantsLayer = true
        layer?.backgroundColor = if isPressedRow {
            NSColor(white: 1.0, alpha: 0.12).cgColor
        } else if isHovered {
            NSColor(white: 1.0, alpha: 0.08).cgColor
        } else {
            NSColor(white: 0.08, alpha: 0.84).cgColor
        }
    }
}

final class OverlayPanelController: NSObject {
    private var panel: NSPanel?
    private var gridView: NSStackView?
    private var tintView: NSView?
    private var appEntries: [NSRunningApplication] = []
    private var blockViews: [AppBlockView] = []
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

    func index(for shortcut: String) -> Int? {
        let normalized = shortcut.lowercased()
        let shortcuts = AppSettings.shared.appShortcuts
        return appEntries.firstIndex { app in
            guard let bundleID = app.bundleIdentifier else { return false }
            return shortcuts[bundleID] == normalized
        }
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
        let ignoredBundleIDs = AppSettings.shared.ignoredBundleIDs

        let apps = NSWorkspace.shared.runningApplications.filter { app in
            let validBundle = app.bundleURL != nil
            let notSelf = app.processIdentifier != ProcessInfo.processInfo.processIdentifier
            let policyOK = includeBackground || app.activationPolicy == .regular
            let notIgnored = app.bundleIdentifier.map { !ignoredBundleIDs.contains($0) } ?? true
            return validBundle && notSelf && policyOK && notIgnored
        }

        appEntries = apps.sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 200),
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
        AppSettings.shared.applyAppearance(to: panel)

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 200))
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = overlayCornerRadius
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.masksToBounds = true
        contentView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.10).cgColor
        contentView.layer?.borderWidth = 1

        contentView.shadow = NSShadow()
        contentView.layer?.shadowColor = NSColor.black.cgColor
        contentView.layer?.shadowOpacity = 0.4
        contentView.layer?.shadowRadius = 30
        contentView.layer?.shadowOffset = NSSize(width: 0, height: -10)

        let blurView = RoundedVisualEffectView()
        blurView.material = .popover
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = overlayCornerRadius
        blurView.layer?.cornerCurve = .continuous
        blurView.layer?.masksToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(blurView)

        let tintView = NSView()
        tintView.wantsLayer = true
        tintView.layer?.cornerRadius = overlayCornerRadius
        tintView.layer?.cornerCurve = .continuous
        tintView.layer?.masksToBounds = true
        tintView.layer?.backgroundColor = overlayTintColor().cgColor
        tintView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tintView)

        let grid = NSStackView()
        grid.orientation = .vertical
        grid.spacing = blockGap
        grid.alignment = .width
        grid.distribution = .fillEqually
        grid.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(grid)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: contentView.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            tintView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tintView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tintView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            grid.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 34),
            grid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 34),
            grid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -34),
            grid.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -34),
        ])

        panel.contentView = contentView
        self.panel = panel
        self.gridView = grid
        self.tintView = tintView
    }

    private func refreshContent() {
        guard let grid = gridView, let panel = panel else { return }

        AppSettings.shared.applyAppearance(to: panel)
        tintView?.layer?.backgroundColor = overlayTintColor().cgColor

        grid.arrangedSubviews.forEach { $0.removeFromSuperview() }
        blockViews.removeAll()

        let count = appEntries.count
        let layoutMode = AppSettings.shared.overlayLayoutMode

        if layoutMode == "list" {
            refreshListContent(in: grid, panel: panel, count: count)
        } else {
            refreshBlockContent(in: grid, panel: panel, count: count)
        }
    }

    private func refreshBlockContent(in grid: NSStackView, panel: NSPanel, count: Int) {
        grid.spacing = blockGap
        grid.distribution = .fillEqually
        grid.alignment = .width

        let rowCount = (count + maxCols - 1) / maxCols
        let actualCols = min(count, maxCols)

        for rowIndex in 0..<rowCount {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = blockGap
            row.alignment = .height
            row.distribution = .fillEqually
            row.translatesAutoresizingMaskIntoConstraints = false

            let start = rowIndex * maxCols
            let end = min(start + maxCols, count)

            for i in start..<end {
                let app = appEntries[i]

                let displayNum: String
                if i < 9 {
                    displayNum = "\(i + 1)"
                } else if i == 9 {
                    displayNum = "0"
                } else {
                    displayNum = "—"
                }

                let block = AppBlockView(app: app, displayNumber: displayNum)
                block.onClick = { [weak self] in
                    self?.hide()
                    app.activate()
                }
                row.addArrangedSubview(makeGridCell(containing: block))
                blockViews.append(block)
            }

            grid.addArrangedSubview(row)
        }

        let hPadding: CGFloat = 68
        let vPadding: CGFloat = 68
        let cols = rowCount > 1 ? maxCols : actualCols
        let panelW = CGFloat(cols) * blockW + CGFloat(cols - 1) * blockGap + hPadding
        let panelH = CGFloat(rowCount) * blockH + CGFloat(max(rowCount - 1, 0)) * blockGap + vPadding

        var frame = panel.frame
        frame.size.width = max(panelW, 160)
        frame.size.height = max(panelH, 120)
        panel.setFrame(frame, display: false)
        panel.layoutIfNeeded()
    }

    private func refreshListContent(in grid: NSStackView, panel: NSPanel, count: Int) {
        grid.spacing = 8
        grid.distribution = .fillEqually
        grid.alignment = .centerX

        for i in 0..<count {
            let app = appEntries[i]
            let displayNum: String
            if i < 9 {
                displayNum = "\(i + 1)"
            } else if i == 9 {
                displayNum = "0"
            } else {
                displayNum = "—"
            }

            grid.addArrangedSubview(makeListRow(app: app, displayNumber: displayNum))
        }

        let hPadding: CGFloat = 68
        let vPadding: CGFloat = 68
        let rowGaps = max(count - 1, 0)
        let panelW = listW + hPadding
        let panelH = CGFloat(count) * listRowH + CGFloat(rowGaps) * grid.spacing + vPadding

        var frame = panel.frame
        frame.size.width = max(panelW, 220)
        frame.size.height = max(panelH, 120)
        panel.setFrame(frame, display: false)
        panel.layoutIfNeeded()
    }

    private func makeListRow(app: NSRunningApplication, displayNumber: String) -> NSView {
        let row = OverlayListRowButton(frame: .zero)
        row.title = ""
        row.isBordered = false
        row.bezelStyle = .regularSquare
        row.translatesAutoresizingMaskIntoConstraints = false
        row.wantsLayer = true
        row.layer?.cornerRadius = 16
        row.layer?.cornerCurve = .continuous
        row.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.84).cgColor
        row.target = self
        row.action = #selector(listRowClicked(_:))
        row.tag = appEntries.firstIndex(of: app) ?? -1

        let numberLabel = NSTextField(labelWithString: displayNumber)
        numberLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        numberLabel.textColor = NSColor(white: 0.74, alpha: 1.0)
        numberLabel.alignment = .center
        numberLabel.wantsLayer = true
        numberLabel.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.10).cgColor
        numberLabel.layer?.cornerRadius = 7
        numberLabel.layer?.cornerCurve = .continuous
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(numberLabel)

        let iconView = NSImageView()
        iconView.image = app.icon ?? NSImage()
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(iconView)

        let nameLabel = NSTextField(labelWithString: app.localizedName ?? "Unknown")
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = NSColor(white: 0.82, alpha: 1.0)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: listRowH),
            row.widthAnchor.constraint(equalToConstant: listW),

            numberLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            numberLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            numberLabel.widthAnchor.constraint(equalToConstant: 28),
            numberLabel.heightAnchor.constraint(equalToConstant: 28),

            iconView.leadingAnchor.constraint(equalTo: numberLabel.trailingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            nameLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])

        return row
    }

    private func makeGridCell(containing block: AppBlockView? = nil) -> NSView {
        let cell = NSView()
        cell.translatesAutoresizingMaskIntoConstraints = false

        if let block = block {
            block.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(block)

            NSLayoutConstraint.activate([
                block.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                block.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                block.widthAnchor.constraint(equalToConstant: blockW),
                block.heightAnchor.constraint(equalToConstant: blockH),
            ])
        }

        return cell
    }

    private func overlayTintColor() -> NSColor {
        AppSettings.shared.overlayBackgroundColor.withAlphaComponent(0.46)
    }

    private func positionPanel() {
        guard let panel = panel else { return }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let screenFrame = screen.frame
        let panelFrame = panel.frame
        let x = screenFrame.midX - panelFrame.width / 2
        let y = screenFrame.midY - panelFrame.height / 2 + 40
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func listRowClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index >= 0, index < appEntries.count else { return }

        let app = appEntries[index]
        hide()
        app.activate()
    }
}
