import Cocoa

private let blockW: CGFloat = 112
private let blockH: CGFloat = 134
private let blockGap: CGFloat = 12
private let maxCols = 4
private let listRowH: CGFloat = 48
private let listW: CGFloat = 360
private let overlayCornerRadius: CGFloat = 38
private let overlayGradientBorderWidth: CGFloat = 2

private final class RoundedVisualEffectView: NSVisualEffectView {
    override func layout() {
        super.layout()
        layer?.cornerRadius = overlayCornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
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

private final class RoundedClipView: NSView {
    private let borderLayer = CAGradientLayer()
    private let borderMask = CAShapeLayer()

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.cornerRadius = overlayCornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.borderWidth = 0
        ensureGradientBorder()
    }

    override func layout() {
        super.layout()
        guard bounds.width > 0, bounds.height > 0 else { return }

        let mask = CAShapeLayer()
        mask.path = CGPath(
            roundedRect: bounds,
            cornerWidth: overlayCornerRadius,
            cornerHeight: overlayCornerRadius,
            transform: nil
        )
        layer?.mask = mask
        updateGradientBorder()
    }

    private func ensureGradientBorder() {
        guard borderLayer.superlayer == nil else { return }

        borderLayer.colors = [
            NSColor(calibratedRed: 0.45, green: 0.75, blue: 1.0, alpha: 0.95).cgColor,
            NSColor(calibratedRed: 0.96, green: 0.52, blue: 0.92, alpha: 0.95).cgColor,
            NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.36, alpha: 0.95).cgColor,
        ]
        borderLayer.startPoint = CGPoint(x: 0, y: 0)
        borderLayer.endPoint = CGPoint(x: 1, y: 1)
        borderLayer.mask = borderMask
        borderLayer.zPosition = 1000
        layer?.addSublayer(borderLayer)
    }

    private func updateGradientBorder() {
        ensureGradientBorder()

        borderLayer.frame = bounds

        let outerPath = CGPath(
            roundedRect: bounds,
            cornerWidth: overlayCornerRadius,
            cornerHeight: overlayCornerRadius,
            transform: nil
        )
        let innerRect = bounds.insetBy(dx: overlayGradientBorderWidth, dy: overlayGradientBorderWidth)
        let innerRadius = max(0, overlayCornerRadius - overlayGradientBorderWidth)
        let innerPath = CGPath(
            roundedRect: innerRect,
            cornerWidth: innerRadius,
            cornerHeight: innerRadius,
            transform: nil
        )

        let path = CGMutablePath()
        path.addPath(outerPath)
        path.addPath(innerPath)

        borderMask.frame = bounds
        borderMask.path = path
        borderMask.fillRule = .evenOdd
    }
}

private final class OverlayShadowView: NSView {
    override func layout() {
        super.layout()
        layer?.shadowPath = CGPath(
            roundedRect: bounds,
            cornerWidth: overlayCornerRadius,
            cornerHeight: overlayCornerRadius,
            transform: nil
        )
    }
}

private final class OverlayListRowButton: NSButton {
    private var isHovered = false
    private var isPressedRow = false
    var isKeyboardSelected = false {
        didSet { updateBackground() }
    }

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
        } else if isKeyboardSelected {
            NSColor(white: 1.0, alpha: 0.11).cgColor
        } else if isHovered {
            NSColor(white: 1.0, alpha: 0.08).cgColor
        } else {
            NSColor(white: 0.08, alpha: 0.84).cgColor
        }
    }
}

private final class KeyBadgeView: NSView {
    private let text: String
    private let attributes: [NSAttributedString.Key: Any]

    init(text: String) {
        self.text = text
        self.attributes = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor(white: 0.74, alpha: 1.0),
        ]
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.10).cgColor
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let size = text.size(withAttributes: attributes)
        let rect = NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        text.draw(in: rect, withAttributes: attributes)
    }
}

final class OverlayPanelController: NSObject {
    private var panel: NSPanel?
    private var gridView: NSStackView?
    private var tintView: NSView?
    private var titleLabel: NSTextField?
    private var footerView: NSView?
    private var workspaceHintLabel: NSTextField?
    private var appEntries: [NSRunningApplication] = []
    private var blockViews: [AppBlockView] = []
    private var listRowButtons: [OverlayListRowButton] = []
    private var selectedIndex: Int?
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

    func selectNextApp() {
        guard !appEntries.isEmpty else { return }
        selectedIndex = ((selectedIndex ?? -1) + 1) % appEntries.count
        updateSelectionAppearance()
    }

    func activateSelectedApp(completion: @escaping (NSRunningApplication) -> Void) -> Bool {
        guard let selectedIndex, selectedIndex < appEntries.count else { return false }
        selectApp(at: selectedIndex, completion: completion)
        return true
    }

    func show() {
        buildAppList()
        guard !appEntries.isEmpty else { return }
        selectedIndex = 0

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

        let contentView = OverlayShadowView(frame: NSRect(x: 0, y: 0, width: 600, height: 200))
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = overlayCornerRadius
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.masksToBounds = false
        contentView.layer?.borderWidth = 0

        contentView.shadow = NSShadow()
        contentView.layer?.shadowColor = NSColor.black.cgColor
        contentView.layer?.shadowOpacity = 0.4
        contentView.layer?.shadowRadius = 30
        contentView.layer?.shadowOffset = NSSize(width: 0, height: -10)

        let clippedView = RoundedClipView()
        clippedView.wantsLayer = true
        clippedView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(clippedView)

        let blurView = RoundedVisualEffectView()
        blurView.material = .popover
        blurView.blendingMode = .withinWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = overlayCornerRadius
        blurView.layer?.cornerCurve = .continuous
        blurView.layer?.masksToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false
        clippedView.addSubview(blurView)

        let tintView = NSView()
        tintView.wantsLayer = true
        tintView.layer?.cornerRadius = overlayCornerRadius
        tintView.layer?.cornerCurve = .continuous
        tintView.layer?.masksToBounds = true
        tintView.layer?.backgroundColor = overlayTintColor().cgColor
        tintView.translatesAutoresizingMaskIntoConstraints = false
        clippedView.addSubview(tintView)

        let grid = NSStackView()
        grid.orientation = .vertical
        grid.spacing = blockGap
        grid.alignment = .width
        grid.distribution = .fillEqually
        grid.translatesAutoresizingMaskIntoConstraints = false
        clippedView.addSubview(grid)

        let titleLabel = NSTextField(labelWithString: "Cmdtab")
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = NSColor(white: 0.82, alpha: 1.0)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        clippedView.addSubview(titleLabel)

        let footerView = NSView()
        footerView.wantsLayer = true
        footerView.layer?.backgroundColor = NSColor(white: 0.035, alpha: 0.82).cgColor
        footerView.translatesAutoresizingMaskIntoConstraints = false
        clippedView.addSubview(footerView)

        let workspaceHintLabel = NSTextField(labelWithString: "switch workspace")
        workspaceHintLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        workspaceHintLabel.textColor = NSColor(white: 0.66, alpha: 1.0)
        workspaceHintLabel.alignment = .right
        workspaceHintLabel.translatesAutoresizingMaskIntoConstraints = false
        footerView.addSubview(workspaceHintLabel)

        let leftArrowBadge = keyBadge("←")
        let rightArrowBadge = keyBadge("→")
        footerView.addSubview(leftArrowBadge)
        footerView.addSubview(rightArrowBadge)

        NSLayoutConstraint.activate([
            clippedView.topAnchor.constraint(equalTo: contentView.topAnchor),
            clippedView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            clippedView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            clippedView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            blurView.topAnchor.constraint(equalTo: clippedView.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: clippedView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: clippedView.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: clippedView.bottomAnchor),

            tintView.topAnchor.constraint(equalTo: clippedView.topAnchor),
            tintView.leadingAnchor.constraint(equalTo: clippedView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: clippedView.trailingAnchor),
            tintView.bottomAnchor.constraint(equalTo: clippedView.bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: clippedView.topAnchor, constant: 22),
            titleLabel.centerXAnchor.constraint(equalTo: clippedView.centerXAnchor),

            footerView.leadingAnchor.constraint(equalTo: clippedView.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: clippedView.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: clippedView.bottomAnchor),
            footerView.heightAnchor.constraint(equalToConstant: 30),

            rightArrowBadge.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            rightArrowBadge.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -34),
            rightArrowBadge.widthAnchor.constraint(equalToConstant: 22),
            rightArrowBadge.heightAnchor.constraint(equalToConstant: 22),

            leftArrowBadge.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            leftArrowBadge.trailingAnchor.constraint(equalTo: rightArrowBadge.leadingAnchor, constant: -6),
            leftArrowBadge.widthAnchor.constraint(equalToConstant: 22),
            leftArrowBadge.heightAnchor.constraint(equalToConstant: 22),

            workspaceHintLabel.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            workspaceHintLabel.trailingAnchor.constraint(equalTo: leftArrowBadge.leadingAnchor, constant: -8),

            grid.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 18),
            grid.leadingAnchor.constraint(equalTo: clippedView.leadingAnchor, constant: 34),
            grid.trailingAnchor.constraint(equalTo: clippedView.trailingAnchor, constant: -34),
            grid.bottomAnchor.constraint(equalTo: footerView.topAnchor, constant: -16),
        ])

        panel.contentView = contentView
        self.panel = panel
        self.gridView = grid
        self.tintView = tintView
        self.titleLabel = titleLabel
        self.footerView = footerView
        self.workspaceHintLabel = workspaceHintLabel
    }

    private func refreshContent() {
        guard let grid = gridView, let panel = panel else { return }

        AppSettings.shared.applyAppearance(to: panel)
        tintView?.layer?.backgroundColor = overlayTintColor().cgColor

        grid.arrangedSubviews.forEach { $0.removeFromSuperview() }
        blockViews.removeAll()
        listRowButtons.removeAll()

        let count = appEntries.count
        let layoutMode = AppSettings.shared.overlayLayoutMode

        if layoutMode == "list" {
            refreshListContent(in: grid, panel: panel, count: count)
        } else {
            refreshBlockContent(in: grid, panel: panel, count: count)
        }
        updateSelectionAppearance()
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
                    InstantSpaceSwitcher.activate(app)
                }
                row.addArrangedSubview(makeGridCell(containing: block))
                blockViews.append(block)
            }

            grid.addArrangedSubview(row)
        }

        let hPadding: CGFloat = 68
        let vPadding: CGFloat = 106
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
        let vPadding: CGFloat = 106
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
        row.layer?.cornerRadius = 8
        row.layer?.cornerCurve = .continuous
        row.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.78).cgColor
        row.target = self
        row.action = #selector(listRowClicked(_:))
        row.tag = appEntries.firstIndex(of: app) ?? -1
        listRowButtons.append(row)

        let numberLabel = keyBadge(displayNumber)
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

        var shortcutLabel: KeyBadgeView?
        if let bundleID = app.bundleIdentifier,
           let shortcut = AppSettings.shared.appShortcuts[bundleID],
           !shortcut.isEmpty {
            let label = keyBadge(shortcut.uppercased())
            row.addSubview(label)
            shortcutLabel = label
        }

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: listRowH),
            row.widthAnchor.constraint(equalToConstant: listW),

            numberLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            numberLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            numberLabel.widthAnchor.constraint(equalToConstant: 22),
            numberLabel.heightAnchor.constraint(equalToConstant: 22),

            iconView.leadingAnchor.constraint(equalTo: numberLabel.trailingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            nameLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])

        if let shortcutLabel {
            NSLayoutConstraint.activate([
                shortcutLabel.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 12),
                shortcutLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
                shortcutLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                shortcutLabel.widthAnchor.constraint(equalToConstant: 22),
                shortcutLabel.heightAnchor.constraint(equalToConstant: 22),
            ])
        } else {
            nameLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12).isActive = true
        }

        return row
    }

    private func updateSelectionAppearance() {
        for row in listRowButtons {
            row.isKeyboardSelected = row.tag == selectedIndex
        }
    }

    private func keyBadge(_ text: String) -> KeyBadgeView {
        KeyBadgeView(text: text)
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
        InstantSpaceSwitcher.activate(app)
    }
}
