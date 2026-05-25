import Cocoa

final class AppBlockView: NSView {
    var onClick: (() -> Void)?

    private var isHovered = false
    private var isPressed = false
    private var bgLayer: CALayer?

    init(app: NSRunningApplication, displayNumber: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 112, height: 134))

        wantsLayer = true
        layer?.cornerRadius = 20
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor(white: 0.055, alpha: 0.88).cgColor

        bgLayer = CALayer()
        bgLayer?.cornerRadius = 20
        bgLayer?.cornerCurve = .continuous
        bgLayer?.masksToBounds = true
        bgLayer?.backgroundColor = nil
        layer?.addSublayer(bgLayer!)

        let numberLabel = NSTextField(labelWithString: displayNumber)
        numberLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        numberLabel.textColor = NSColor(white: 0.72, alpha: 1.0)
        numberLabel.alignment = .center
        numberLabel.wantsLayer = true
        numberLabel.layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.92).cgColor
        numberLabel.layer?.cornerRadius = 7
        numberLabel.layer?.cornerCurve = .continuous
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(numberLabel)

        let iconView = NSImageView()
        iconView.image = app.icon ?? NSImage()
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        let nameLabel = NSTextField(labelWithString: app.localizedName ?? "")
        nameLabel.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        nameLabel.textColor = NSColor(white: 0.72, alpha: 1.0)
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)
        addSubview(numberLabel, positioned: .above, relativeTo: iconView)

        NSLayoutConstraint.activate([
            numberLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            numberLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            numberLabel.widthAnchor.constraint(equalToConstant: 28),
            numberLabel.heightAnchor.constraint(equalToConstant: 28),

            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 30),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 54),
            iconView.heightAnchor.constraint(equalToConstant: 54),

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),
        ])

        let tracking = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let tracking = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        animateHighlight()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isPressed = false
        animateHighlight()
    }

    override func mouseDown(with event: NSEvent) {
        if isHovered {
            isPressed = true
            animateHighlight()
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isPressed {
            isPressed = false
            animateHighlight()
            onClick?()
        }
    }

    private func animateHighlight() {
        let color: CGColor?
        if isPressed {
            color = NSColor(white: 1.0, alpha: 0.16).cgColor
        } else if isHovered {
            color = NSColor(white: 1.0, alpha: 0.08).cgColor
        } else {
            color = nil
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.allowsImplicitAnimation = true
            bgLayer?.backgroundColor = color
        }
    }

    override func layout() {
        super.layout()
        bgLayer?.frame = bounds
    }
}
