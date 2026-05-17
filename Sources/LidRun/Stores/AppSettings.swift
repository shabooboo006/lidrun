import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let lidRunEnabled = "lidRunEnabled"
        static let preventSystemSleep = "preventSystemSleep"
        static let preventDisplaySleep = "preventDisplaySleep"
        static let preventScreenLock = "preventScreenLock"
        static let selectedDuration = "selectedDuration"
        static let customMinutes = "customMinutes"
        static let launchAtLogin = "launchAtLogin"
        static let activateOnLaunch = "activateOnLaunch"
        static let quickToggleClick = "quickToggleClick"
        static let notificationsEnabled = "notificationsEnabled"
        static let coloredIcon = "coloredIcon"
        static let acOnlyProtection = "acOnlyProtection"
        static let lowBatteryProtection = "lowBatteryProtection"
        static let thermalProtection = "thermalProtection"
        static let globalHotKeyEnabled = "globalHotKeyEnabled"
        static let savedDisableSleepValue = "savedDisableSleepValue"
        static let lidRunWasActive = "lidRunWasActive"
    }

    private let defaults: UserDefaults

    @Published var lidRunEnabled: Bool { didSet { defaults.set(lidRunEnabled, forKey: Key.lidRunEnabled) } }
    @Published var preventSystemSleep: Bool { didSet { defaults.set(preventSystemSleep, forKey: Key.preventSystemSleep) } }
    @Published var preventDisplaySleep: Bool { didSet { defaults.set(preventDisplaySleep, forKey: Key.preventDisplaySleep) } }
    @Published var preventScreenLock: Bool { didSet { defaults.set(preventScreenLock, forKey: Key.preventScreenLock) } }
    @Published var selectedDuration: DurationOption { didSet { defaults.set(selectedDuration.rawValue, forKey: Key.selectedDuration) } }
    @Published var customMinutes: Int { didSet { defaults.set(customMinutes, forKey: Key.customMinutes) } }
    @Published var launchAtLogin: Bool { didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) } }
    @Published var activateOnLaunch: Bool { didSet { defaults.set(activateOnLaunch, forKey: Key.activateOnLaunch) } }
    @Published var quickToggleClick: Bool { didSet { defaults.set(quickToggleClick, forKey: Key.quickToggleClick) } }
    @Published var notificationsEnabled: Bool { didSet { defaults.set(notificationsEnabled, forKey: Key.notificationsEnabled) } }
    @Published var coloredIcon: Bool { didSet { defaults.set(coloredIcon, forKey: Key.coloredIcon) } }
    @Published var acOnlyProtection: Bool { didSet { defaults.set(acOnlyProtection, forKey: Key.acOnlyProtection) } }
    @Published var lowBatteryProtection: Bool { didSet { defaults.set(lowBatteryProtection, forKey: Key.lowBatteryProtection) } }
    @Published var thermalProtection: Bool { didSet { defaults.set(thermalProtection, forKey: Key.thermalProtection) } }
    @Published var globalHotKeyEnabled: Bool { didSet { defaults.set(globalHotKeyEnabled, forKey: Key.globalHotKeyEnabled) } }

    var savedDisableSleepValue: Int? {
        get {
            guard defaults.object(forKey: Key.savedDisableSleepValue) != nil else { return nil }
            return defaults.integer(forKey: Key.savedDisableSleepValue)
        }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.savedDisableSleepValue)
            } else {
                defaults.removeObject(forKey: Key.savedDisableSleepValue)
            }
        }
    }

    var lidRunWasActive: Bool {
        get { defaults.bool(forKey: Key.lidRunWasActive) }
        set { defaults.set(newValue, forKey: Key.lidRunWasActive) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lidRunEnabled = defaults.object(forKey: Key.lidRunEnabled) as? Bool ?? false
        preventSystemSleep = defaults.object(forKey: Key.preventSystemSleep) as? Bool ?? true
        preventDisplaySleep = defaults.object(forKey: Key.preventDisplaySleep) as? Bool ?? false
        preventScreenLock = defaults.object(forKey: Key.preventScreenLock) as? Bool ?? false
        selectedDuration = DurationOption(rawValue: defaults.string(forKey: Key.selectedDuration) ?? "") ?? .unlimited
        customMinutes = max(1, defaults.object(forKey: Key.customMinutes) as? Int ?? 120)
        launchAtLogin = defaults.object(forKey: Key.launchAtLogin) as? Bool ?? false
        activateOnLaunch = defaults.object(forKey: Key.activateOnLaunch) as? Bool ?? false
        quickToggleClick = defaults.object(forKey: Key.quickToggleClick) as? Bool ?? false
        notificationsEnabled = defaults.object(forKey: Key.notificationsEnabled) as? Bool ?? true
        coloredIcon = defaults.object(forKey: Key.coloredIcon) as? Bool ?? false
        // 默认关闭：用户的核心场景是断电也要能合盖不休眠（见 spec §2）。
        // 低电量/过热保护仍默认开启作为安全兜底。
        acOnlyProtection = defaults.object(forKey: Key.acOnlyProtection) as? Bool ?? false
        lowBatteryProtection = defaults.object(forKey: Key.lowBatteryProtection) as? Bool ?? true
        thermalProtection = defaults.object(forKey: Key.thermalProtection) as? Bool ?? true
        globalHotKeyEnabled = defaults.object(forKey: Key.globalHotKeyEnabled) as? Bool ?? true
    }
}
