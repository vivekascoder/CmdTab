import Cocoa

final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    var showBackgroundApps: Bool {
        get { defaults.bool(forKey: "showBackgroundApps") }
        set {
            defaults.set(newValue, forKey: "showBackgroundApps")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var instantSpaceSwitching: Bool {
        get { defaults.bool(forKey: "instantSpaceSwitching") }
        set {
            defaults.set(newValue, forKey: "instantSpaceSwitching")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var panelAppearance: String {
        get { defaults.string(forKey: "panelAppearance") ?? "auto" }
        set {
            defaults.set(newValue, forKey: "panelAppearance")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var overlayLayoutMode: String {
        get { defaults.string(forKey: "overlayLayoutMode") ?? "list" }
        set {
            defaults.set(newValue, forKey: "overlayLayoutMode")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var overlayBackgroundColor: NSColor {
        get {
            NSColor(hexString: defaults.string(forKey: "overlayBackgroundColor") ?? "#0A0A0A")
                ?? NSColor(white: 0.04, alpha: 1.0)
        }
        set {
            defaults.set(newValue.hexString, forKey: "overlayBackgroundColor")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var monitoringActive: Bool {
        get { defaults.bool(forKey: "monitoringActive") }
        set { defaults.set(newValue, forKey: "monitoringActive") }
    }

    var ignoredBundleIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: "ignoredBundleIDs") ?? []) }
        set {
            defaults.set(Array(newValue).sorted(), forKey: "ignoredBundleIDs")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var appShortcuts: [String: String] {
        get { defaults.dictionary(forKey: "appShortcuts") as? [String: String] ?? [:] }
        set {
            defaults.set(newValue, forKey: "appShortcuts")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    func setIgnored(_ ignored: Bool, for bundleID: String) {
        var ignoredIDs = ignoredBundleIDs
        if ignored {
            ignoredIDs.insert(bundleID)
        } else {
            ignoredIDs.remove(bundleID)
        }
        ignoredBundleIDs = ignoredIDs
    }

    func setShortcut(_ shortcut: String?, for bundleID: String) {
        var shortcuts = appShortcuts
        let normalized = shortcut?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .first
            .map(String.init)

        if let normalized, normalized.rangeOfCharacter(from: CharacterSet.alphanumerics) != nil {
            shortcuts[bundleID] = normalized
        } else {
            shortcuts.removeValue(forKey: bundleID)
        }
        appShortcuts = shortcuts
    }

    func applyAppearance(to window: NSWindow) {
        switch panelAppearance {
        case "dark":
            window.appearance = NSAppearance(named: .darkAqua)
        case "light":
            window.appearance = NSAppearance(named: .aqua)
        default:
            window.appearance = nil
        }
    }

    private init() {
        defaults.register(defaults: [
            "showBackgroundApps": false,
            "instantSpaceSwitching": false,
            "panelAppearance": "dark",
            "overlayLayoutMode": "list",
            "overlayBackgroundColor": "#0A0A0A",
            "monitoringActive": false,
            "ignoredBundleIDs": [],
            "appShortcuts": [:],
        ])
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("CmdTabSettingsChanged")
}

private extension NSColor {
    convenience init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }

        guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }

        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255

        self.init(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }

    var hexString: String {
        let rgb = usingColorSpace(.deviceRGB) ?? self
        let red = max(0, min(255, Int(round(rgb.redComponent * 255))))
        let green = max(0, min(255, Int(round(rgb.greenComponent * 255))))
        let blue = max(0, min(255, Int(round(rgb.blueComponent * 255))))

        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
