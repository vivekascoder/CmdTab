import Cocoa

private let workspaceOverlayCornerRadius: CGFloat = 24
private let workspaceOverlayBorderWidth: CGFloat = 2

private final class WorkspaceOverlayView: NSVisualEffectView {
    private let borderLayer = CAGradientLayer()
    private let borderMask = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupBorder()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBorder()
    }

    override func layout() {
        super.layout()
        updateBorder()
    }

    private func setupBorder() {
        wantsLayer = true
        borderLayer.colors = [
            NSColor(calibratedRed: 0.45, green: 0.75, blue: 1.0, alpha: 0.95).cgColor,
            NSColor(calibratedRed: 0.96, green: 0.52, blue: 0.92, alpha: 0.95).cgColor,
            NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.36, alpha: 0.95).cgColor,
        ]
        borderLayer.startPoint = CGPoint(x: 0, y: 0)
        borderLayer.endPoint = CGPoint(x: 1, y: 1)
        borderLayer.mask = borderMask
        layer?.addSublayer(borderLayer)
    }

    private func updateBorder() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        borderLayer.frame = bounds

        let outerPath = CGPath(
            roundedRect: bounds,
            cornerWidth: workspaceOverlayCornerRadius,
            cornerHeight: workspaceOverlayCornerRadius,
            transform: nil
        )
        let innerRect = bounds.insetBy(dx: workspaceOverlayBorderWidth, dy: workspaceOverlayBorderWidth)
        let innerRadius = max(0, workspaceOverlayCornerRadius - workspaceOverlayBorderWidth)
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

final class WorkspaceOverlayController: NSObject {
    private var panel: NSPanel?
    private var captionLabel: NSTextField?
    private var numberLabel: NSTextField?
    private var hideWorkItem: DispatchWorkItem?

    func showCurrentWorkspace() {
        show(position: InstantSpaceSwitcher.currentWorkspacePosition())
    }

    func show(position: InstantSpaceSwitcher.WorkspacePosition?) {
        if panel == nil {
            createPanel()
        }

        numberLabel?.stringValue = desktopNumberText(for: position?.desktopNumber)
        positionPanel()

        hideWorkItem?.cancel()
        panel?.alphaValue = panel?.isVisible == true ? 1 : 0
        panel?.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.10
            panel?.animator().alphaValue = 1
        }
    }

    func dismiss() {
        hideWorkItem?.cancel()
        panel?.orderOut(nil)
    }

    func dismissSoon() {
        hideWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.panel?.orderOut(nil)
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: workItem)
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 168, height: 138),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        AppSettings.shared.applyAppearance(to: panel)

        let contentView = WorkspaceOverlayView(frame: NSRect(x: 0, y: 0, width: 168, height: 138))
        contentView.material = .hudWindow
        contentView.blendingMode = .withinWindow
        contentView.state = .active
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = workspaceOverlayCornerRadius
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.masksToBounds = true

        let tintView = NSView()
        tintView.wantsLayer = true
        tintView.layer?.backgroundColor = NSColor(white: 0.03, alpha: 0.52).cgColor
        tintView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tintView)

        let captionLabel = NSTextField(labelWithString: "Desktop no")
        captionLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        captionLabel.textColor = NSColor(white: 0.78, alpha: 1.0)
        captionLabel.alignment = .center
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(captionLabel)

        let numberLabel = NSTextField(labelWithString: "1")
        numberLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 68, weight: .bold)
        numberLabel.textColor = NSColor(white: 0.96, alpha: 1.0)
        numberLabel.alignment = .center
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(numberLabel)

        NSLayoutConstraint.activate([
            tintView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tintView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tintView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            captionLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            captionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            captionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            numberLabel.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 4),
            numberLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            numberLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            numberLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ])

        panel.contentView = contentView
        self.panel = panel
        self.captionLabel = captionLabel
        self.numberLabel = numberLabel
    }

    private func positionPanel() {
        guard let panel = panel else { return }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let screenFrame = screen.frame
        let panelFrame = panel.frame
        let x = screenFrame.midX - panelFrame.width / 2
        let y = screenFrame.midY - panelFrame.height / 2 + 96
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func desktopNumberText(for number: Int?) -> String {
        guard let number else { return "-" }
        return "\(number)"
    }
}
