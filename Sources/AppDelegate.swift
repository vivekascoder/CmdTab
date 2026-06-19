import Cocoa
import CoreGraphics
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum KeyCode {
        static let escape: Int64 = 53
        static let tab: Int64 = 48
        static let returnKey: Int64 = 36
        static let keypadEnter: Int64 = 76
        static let rightCommand: Int64 = 54
        static let leftCommand: Int64 = 55
        static let leftArrow: Int64 = 123
        static let rightArrow: Int64 = 124
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var overlayController: OverlayPanelController!
    private var workspaceOverlayController: WorkspaceOverlayController!
    private var statusBarController: StatusBarController!
    private var isRightCmdDown = false
    private var isWorkspaceModeActive = false
    private var suppressRightCmdUntilRelease = false
    private var accessibilityRetryTimer: Timer?

    private let log = OSLog(subsystem: "com.cmdtab.app", category: "events")

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlayController = OverlayPanelController()
        workspaceOverlayController = WorkspaceOverlayController()

        statusBarController = StatusBarController()
        statusBarController.setup()
        statusBarController.updateState(monitoringActive: false)
        statusBarController.onTestOverlay = { [weak self] in
            self?.overlayController.show()
        }
        statusBarController.onSettingsChanged = { [weak self] in
            self?.overlayController.dismiss()
        }

        promptForAccessibility()
        setupEventTap()
    }

    func applicationWillTerminate(_ notification: Notification) {
        accessibilityRetryTimer?.invalidate()
        teardownEventTap()
    }

    private func promptForAccessibility() {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }

    private func setupEventTap() {
        teardownEventTap()

        let maskedKeyDown   = 1 << CGEventType.keyDown.rawValue
        let maskedKeyUp     = 1 << CGEventType.keyUp.rawValue
        let maskedFlags     = 1 << CGEventType.flagsChanged.rawValue
        let eventMask = CGEventMask(maskedKeyDown | maskedKeyUp | maskedFlags)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
                return delegate.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        )

        guard let tap = eventTap else {
            os_log(.error, log: log, "CGEvent.tapCreate returned nil — accessibility not granted?")
            AppSettings.shared.monitoringActive = false
            statusBarController.updateState(monitoringActive: false)
            startAccessibilityRetryTimer()
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        os_log(.info, log: log, "Event tap created — monitoring right Command (keyCode 54)")
        AppSettings.shared.monitoringActive = true
        statusBarController.updateState(monitoringActive: true)
        accessibilityRetryTimer?.invalidate()
        accessibilityRetryTimer = nil
    }

    private func teardownEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func startAccessibilityRetryTimer() {
        accessibilityRetryTimer?.invalidate()
        accessibilityRetryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if AXIsProcessTrusted() {
                os_log(.info, log: self.log, "Accessibility granted — retrying event tap")
                self.setupEventTap()
            }
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {

        case .flagsChanged:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            if keyCode == KeyCode.leftCommand {
                return Unmanaged.passRetained(event)
            }

            if keyCode == KeyCode.rightCommand {
                let rightCmdNowDown = event.flags.contains(.maskCommand)
                let optionDown = event.flags.contains(.maskAlternate)

                if rightCmdNowDown {
                    isRightCmdDown = true
                    if suppressRightCmdUntilRelease {
                        return nil
                    }

                    os_log(.debug, log: log, "Right Cmd PRESSED")
                    DispatchQueue.main.async { [weak self] in
                        if optionDown {
                            self?.enterWorkspaceMode()
                        } else {
                            self?.overlayController.show()
                        }
                    }
                } else {
                    isRightCmdDown = false
                    isWorkspaceModeActive = false
                    suppressRightCmdUntilRelease = false
                    os_log(.debug, log: log, "Right Cmd RELEASED")
                    DispatchQueue.main.async { [weak self] in
                        self?.overlayController.dismiss()
                        self?.workspaceOverlayController.dismiss()
                    }
                }
                return nil
            }

            if isRightCmdDown {
                let optionDown = event.flags.contains(.maskAlternate)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if optionDown {
                        self.enterWorkspaceMode()
                    } else if self.isWorkspaceModeActive {
                        self.exitWorkspaceMode()
                    }
                }
                return nil
            }

            return Unmanaged.passRetained(event)

        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            if keyCode == KeyCode.rightCommand {
                if !isRightCmdDown && !suppressRightCmdUntilRelease {
                    isRightCmdDown = true
                    let optionDown = event.flags.contains(.maskAlternate)
                    os_log(.debug, log: log, "Right Cmd keyDown (fallback)")
                    DispatchQueue.main.async { [weak self] in
                        if optionDown {
                            self?.enterWorkspaceMode()
                        } else {
                            self?.overlayController.show()
                        }
                    }
                }
                return nil
            }

            guard isRightCmdDown else { return Unmanaged.passRetained(event) }

            if keyCode == KeyCode.escape {
                os_log(.debug, log: log, "Escape — dismissing overlay")
                suppressRightCmdUntilRelease = true
                DispatchQueue.main.async { [weak self] in
                    self?.overlayController.dismiss()
                }
                return nil
            }

            if keyCode == KeyCode.leftArrow || keyCode == KeyCode.rightArrow {
                let direction: InstantSpaceSwitcher.Direction = keyCode == KeyCode.rightArrow ? .right : .left
                os_log(.debug, log: log, "Arrow -> workspace switch")
                let optionDown = event.flags.contains(.maskAlternate)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if optionDown || self.isWorkspaceModeActive {
                        self.enterWorkspaceMode()
                        let position = InstantSpaceSwitcher.switchWorkspace(direction)
                        self.workspaceOverlayController.show(position: position)
                    } else {
                        _ = InstantSpaceSwitcher.switchWorkspace(direction)
                    }
                }
                return nil
            }

            if keyCode == KeyCode.tab {
                os_log(.debug, log: log, "Tab -> next selected app")
                DispatchQueue.main.async { [weak self] in
                    self?.overlayController.selectNextApp()
                }
                return nil
            }

            if keyCode == KeyCode.returnKey || keyCode == KeyCode.keypadEnter {
                os_log(.debug, log: log, "Enter -> selected app")
                suppressRightCmdUntilRelease = true
                DispatchQueue.main.async { [weak self] in
                    _ = self?.overlayController.activateSelectedApp { app in
                        InstantSpaceSwitcher.activate(app)
                    }
                }
                return nil
            }

            if let index = overlayController.index(for: keyCode) {
                let optionDown = event.flags.contains(.maskAlternate)
                if optionDown || isWorkspaceModeActive {
                    let desktopNumber = index == 9 ? 10 : index + 1
                    os_log(.debug, log: log, "Number -> workspace %{public}d", desktopNumber)
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.enterWorkspaceMode()
                        let position = InstantSpaceSwitcher.switchWorkspace(toDesktopNumber: desktopNumber)
                        self.workspaceOverlayController.show(position: position)
                    }
                    return nil
                }

                os_log(.debug, log: log, "Number -> index %{public}d", index)
                suppressRightCmdUntilRelease = true
                DispatchQueue.main.async { [weak self] in
                    self?.overlayController.selectApp(at: index) { app in
                        InstantSpaceSwitcher.activate(app)
                    }
                }
                return nil
            }

            if let shortcut = eventShortcutCharacter(event),
               let index = overlayController.index(for: shortcut) {
                os_log(.debug, log: log, "Shortcut -> index %{public}d", index)
                suppressRightCmdUntilRelease = true
                DispatchQueue.main.async { [weak self] in
                    self?.overlayController.selectApp(at: index) { app in
                        InstantSpaceSwitcher.activate(app)
                    }
                }
                return nil
            }

            return nil

        case .keyUp:
            if event.getIntegerValueField(.keyboardEventKeycode) == KeyCode.rightCommand {
                os_log(.debug, log: log, "Right Cmd keyUp")
                if isRightCmdDown {
                    isRightCmdDown = false
                    isWorkspaceModeActive = false
                    suppressRightCmdUntilRelease = false
                    DispatchQueue.main.async { [weak self] in
                        self?.overlayController.dismiss()
                        self?.workspaceOverlayController.dismiss()
                    }
                }
                return nil
            }
            guard isRightCmdDown else { return Unmanaged.passRetained(event) }
            return nil

        default:
            break
        }

        return Unmanaged.passRetained(event)
    }

    private func enterWorkspaceMode() {
        overlayController.dismiss()
        isWorkspaceModeActive = true
        workspaceOverlayController.showCurrentWorkspace()
    }

    private func exitWorkspaceMode() {
        isWorkspaceModeActive = false
        workspaceOverlayController.dismissSoon()
        overlayController.show()
    }

    private func eventShortcutCharacter(_ event: CGEvent) -> String? {
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: chars.count, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else { return nil }

        guard let scalar = UnicodeScalar(chars[0]) else { return nil }
        let character = String(Character(scalar)).lowercased()
        guard character.rangeOfCharacter(from: CharacterSet.alphanumerics) != nil else { return nil }
        return character
    }
}
