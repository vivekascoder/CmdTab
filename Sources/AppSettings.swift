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

    var panelAppearance: String {
        get { defaults.string(forKey: "panelAppearance") ?? "auto" }
        set {
            defaults.set(newValue, forKey: "panelAppearance")
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var monitoringActive: Bool {
        get { defaults.bool(forKey: "monitoringActive") }
        set { defaults.set(newValue, forKey: "monitoringActive") }
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
            "panelAppearance": "auto",
            "monitoringActive": false,
        ])
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("CmdTabSettingsChanged")
}
