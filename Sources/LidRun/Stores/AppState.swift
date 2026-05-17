import AppKit
import Foundation
import IOKit

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var lidRunState: LidRunState = .off
    @Published private(set) var powerSnapshot: PowerSnapshot = .unknown
    @Published private(set) var remainingSeconds: TimeInterval?
    @Published private(set) var sessionEndsAt: Date?
    @Published private(set) var statusMessage = "未激活"

    let settings: AppSettings
    let helperAuthorization: HelperAuthorizationService

    private let sleepAssertion = SleepAssertionController()
    private let powerMonitor = PowerSourceMonitor()
    private let notifications = NotificationService()
    private let loginItemService = LoginItemService()
    private let hotKeyController = GlobalHotKeyController()
    private var countdownTimer: Timer?
    private var startupTask: Task<Void, Never>?
    private var clamshellTimer: Timer?
    private var lastClamshellClosed = false
    private var lastDisplaySleepAt: Date = .distantPast

    init(
        settings: AppSettings = AppSettings(),
        helperAuthorization: HelperAuthorizationService = HelperAuthorizationService()
    ) {
        self.settings = settings
        self.helperAuthorization = helperAuthorization
        powerSnapshot = powerMonitor.snapshot

        powerMonitor.onChange = { [weak self] snapshot in
            self?.powerSnapshot = snapshot
            self?.enforceProtectionRules(trigger: "电源状态变化")
        }
    }

    func start() {
        notifications.requestAuthorizationIfNeeded()
        powerMonitor.start()
        configureHotKey()

        startupTask = Task { [weak self] in
            guard let self else { return }
            await self.helperAuthorization.refreshStatus()
            await self.restoreStaleLidRunStateIfNeeded()
            if self.settings.activateOnLaunch {
                await self.setActive(true)
            }
        }
    }

    func shutdown() async {
        startupTask?.cancel()
        countdownTimer?.invalidate()
        countdownTimer = nil
        stopClamshellDisplaySleepWatch()
        sleepAssertion.releaseAll()
        if lidRunState == .running || settings.lidRunWasActive || settings.savedDisableSleepValue != nil {
            await disableLidRun(notify: false)
        }
        powerMonitor.stop()
        hotKeyController.stop()
        helperAuthorization.client.invalidate()
        AppLog.app.info("Application shutdown completed")
    }

    func setActive(_ active: Bool) async {
        if active {
            await activateSession()
        } else {
            await deactivateSession(reason: "手动关闭", notify: true)
        }
    }

    func toggleActive() {
        Task { await setActive(!isActive) }
    }

    func setDuration(_ duration: DurationOption) {
        settings.selectedDuration = duration
        if isActive {
            configureDurationTimer()
        }
        updateStatusMessage()
    }

    func setCustomMinutes(_ minutes: Int) {
        settings.customMinutes = max(1, minutes)
        if isActive && settings.selectedDuration == .custom {
            configureDurationTimer()
        }
        updateStatusMessage()
    }

    func setLidRunEnabled(_ enabled: Bool) {
        settings.lidRunEnabled = enabled
        Task {
            if enabled {
                if !isActive {
                    await setActive(true)
                } else {
                    await enableLidRun()
                }
            } else {
                await disableLidRun(notify: true)
            }
        }
    }

    func updateSleepAssertions() {
        guard isActive else { return }
        sleepAssertion.update(
            preventSystemSleep: settings.preventSystemSleep,
            preventDisplaySleep: settings.preventDisplaySleep
        )
        updateStatusMessage()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        settings.launchAtLogin = enabled
        do {
            try loginItemService.setLaunchAtLogin(enabled)
        } catch {
            AppLog.app.error("Failed to update login item: \(error.localizedDescription, privacy: .public)")
            notifications.send(
                title: "登录启动设置失败",
                body: error.localizedDescription,
                enabled: settings.notificationsEnabled
            )
        }
    }

    func configureHotKey() {
        hotKeyController.setEnabled(settings.globalHotKeyEnabled) { [weak self] in
            self?.toggleActive()
        }
    }

    func requestHelperAuthorization() {
        Task {
            await helperAuthorization.installOrRequestAuthorization()
            if settings.lidRunEnabled && isActive {
                await enableLidRun()
            }
        }
    }

    func showAbout() {
        let info = Bundle.main.infoDictionary
        let shortVersion = (info?["CFBundleShortVersionString"] as? String) ?? "开发版"
        let build = info?["CFBundleVersion"] as? String
        let versionLine = build.map { "版本 \(shortVersion) (\($0))" } ?? "版本 \(shortVersion)"

        let alert = NSAlert()
        alert.messageText = "LidRun \(shortVersion)"
        alert.informativeText = """
        \(versionLine)

        原生 macOS 菜单栏工具，用于防止空闲睡眠，并在授权后支持合盖继续运行。

        https://github.com/shabooboo006/lidrun
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private func activateSession() async {
        guard !isActive else {
            updateSleepAssertions()
            if settings.lidRunEnabled {
                await enableLidRun()
            }
            return
        }

        isActive = true
        sleepAssertion.update(
            preventSystemSleep: settings.preventSystemSleep,
            preventDisplaySleep: settings.preventDisplaySleep
        )
        configureDurationTimer()

        if settings.lidRunEnabled {
            await enableLidRun()
        } else {
            lidRunState = .off
        }

        updateStatusMessage()
        notifications.send(title: "LidRun 已激活", body: statusMessage, enabled: settings.notificationsEnabled)
        AppLog.app.info("Session activated")
    }

    private func deactivateSession(reason: String, notify: Bool) async {
        guard isActive || lidRunState == .running else { return }

        isActive = false
        countdownTimer?.invalidate()
        countdownTimer = nil
        sessionEndsAt = nil
        remainingSeconds = nil
        sleepAssertion.releaseAll()
        await disableLidRun(notify: false)
        updateStatusMessage()

        if notify {
            notifications.send(title: "LidRun 已关闭", body: reason, enabled: settings.notificationsEnabled)
        }
        AppLog.app.info("Session deactivated: \(reason, privacy: .public)")
    }

    private func enableLidRun() async {
        let decision = protectionDecision(for: powerSnapshot)
        guard decision.allowed else {
            lidRunState = .blocked(decision.reason ?? "保护规则已阻止")
            settings.lidRunWasActive = false
            notifications.send(
                title: "合盖运行未启用",
                body: decision.reason ?? "保护规则已阻止",
                enabled: settings.notificationsEnabled
            )
            updateStatusMessage()
            return
        }

        if helperAuthorization.status != .installed {
            await helperAuthorization.refreshStatus()
            guard helperAuthorization.status == .installed else {
                lidRunState = .blocked(helperAuthorization.status.title)
                updateStatusMessage()
                return
            }
        }

        lidRunState = .enabling
        do {
            if settings.savedDisableSleepValue == nil {
                settings.savedDisableSleepValue = try await helperAuthorization.client.readDisableSleep()
            }
            try await helperAuthorization.client.setDisableSleep(true)
            let verifiedValue = try await helperAuthorization.client.readDisableSleep()
            guard verifiedValue == 1 else {
                throw HelperClientError.operationFailed("helper 已执行设置，但系统 disablesleep 仍为 \(verifiedValue)")
            }
            settings.lidRunWasActive = true
            lidRunState = .running
            startClamshellDisplaySleepWatch()
            updateStatusMessage()
            notifications.send(title: "合盖运行已启用", body: "合上盖子后系统继续运行，屏幕会自动熄灭省电。", enabled: settings.notificationsEnabled)
            AppLog.power.info("Lid close mode enabled")
        } catch {
            if let restoreValue = settings.savedDisableSleepValue, !settings.lidRunWasActive {
                try? await helperAuthorization.client.restoreDisableSleep(restoreValue)
                settings.savedDisableSleepValue = nil
            }
            lidRunState = .blocked(helperAuthorization.status == .installed ? "设置失败" : helperAuthorization.status.title)
            helperAuthorization.recordError(error.localizedDescription)
            updateStatusMessage()
            notifications.send(title: "合盖运行异常", body: error.localizedDescription, enabled: settings.notificationsEnabled)
            AppLog.power.error("Failed to enable lid run: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func disableLidRun(notify: Bool) async {
        stopClamshellDisplaySleepWatch()
        guard settings.lidRunWasActive || lidRunState == .running || settings.savedDisableSleepValue != nil else {
            lidRunState = .off
            return
        }

        lidRunState = .restoring
        let restoreValue = settings.savedDisableSleepValue ?? 0

        do {
            if helperAuthorization.status != .installed {
                await helperAuthorization.refreshStatus()
            }
            if helperAuthorization.status == .installed {
                try await helperAuthorization.client.restoreDisableSleep(restoreValue)
                settings.savedDisableSleepValue = nil
                settings.lidRunWasActive = false
                lidRunState = .off
                AppLog.power.info("Lid close mode restored to \(restoreValue, privacy: .public)")
                if notify {
                    notifications.send(title: "合盖运行已关闭", body: "已恢复原系统电源设置。", enabled: settings.notificationsEnabled)
                }
            } else {
                lidRunState = .blocked("恢复需 helper")
                notifications.send(title: "睡眠保护异常", body: "无法连接 helper，请重新授权后恢复设置。", enabled: settings.notificationsEnabled)
            }
        } catch {
            lidRunState = .blocked("恢复失败")
            notifications.send(title: "睡眠保护异常", body: error.localizedDescription, enabled: settings.notificationsEnabled)
            AppLog.power.error("Failed to restore lid close mode: \(error.localizedDescription, privacy: .public)")
        }

        updateStatusMessage()
    }

    private func restoreStaleLidRunStateIfNeeded() async {
        guard settings.lidRunWasActive || settings.savedDisableSleepValue != nil else { return }
        AppLog.power.info("Found stale lid run state; attempting restore")
        await disableLidRun(notify: true)
    }

    private func configureDurationTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil

        guard let duration = settings.selectedDuration.seconds(customMinutes: settings.customMinutes) else {
            sessionEndsAt = nil
            remainingSeconds = nil
            updateStatusMessage()
            return
        }

        sessionEndsAt = Date().addingTimeInterval(duration)
        remainingSeconds = duration
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickCountdown() }
        }
    }

    private func tickCountdown() {
        guard let sessionEndsAt else { return }
        let remaining = max(0, sessionEndsAt.timeIntervalSinceNow)
        remainingSeconds = remaining
        updateStatusMessage()
        if remaining <= 0 {
            Task { await deactivateSession(reason: "持续时间已到", notify: true) }
        }
    }

    // MARK: - 合盖时强制熄屏（省电）
    //
    // 核心“系统不休眠”靠 disablesleep + NoIdleSleep assertion，已验证有效。
    // 但合盖且无外接显示器时，macOS 会把显示链路保持为“on”（powerd:
    // "Prevent sleep while display is on"），白白耗电。这里在“合盖运行中
    // 且盖子物理闭合”时主动 `pmset displaysleepnow`（经 helper 白名单），
    // 让屏幕真正熄灭；系统仍由 NoIdleSleep 保持运行。严格只在盖子闭合时
    // 触发，绝不在开盖正常使用时弄黑用户屏幕。

    private func startClamshellDisplaySleepWatch() {
        clamshellTimer?.invalidate()
        lastClamshellClosed = false
        lastDisplaySleepAt = .distantPast
        clamshellTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.clamshellTick() }
        }
    }

    private func stopClamshellDisplaySleepWatch() {
        clamshellTimer?.invalidate()
        clamshellTimer = nil
        lastClamshellClosed = false
    }

    private func clamshellTick() {
        guard lidRunState == .running else {
            stopClamshellDisplaySleepWatch()
            return
        }
        guard Self.isClamshellClosed() else {
            lastClamshellClosed = false
            return
        }
        // 接了外接显示器（经典 clamshell）时不强制熄屏，避免弄黑用户正在用的外屏。
        // 仅命中用户场景：合盖 + 无外接显示器的“真无头”状态。
        guard !Self.hasExternalDisplay() else {
            lastClamshellClosed = false
            return
        }
        // 盖子闭合且无外接：刚闭合时立即熄屏；持续闭合时每 ~25s 兜底重发
        // （powerd 在合盖运行态下可能重新点亮显示链路）。
        let now = Date()
        let justClosed = !lastClamshellClosed
        let staleEnough = now.timeIntervalSince(lastDisplaySleepAt) > 25
        lastClamshellClosed = true
        guard justClosed || staleEnough else { return }
        lastDisplaySleepAt = now
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.helperAuthorization.client.displaySleepNow()
                AppLog.power.info("Forced display sleep (clamshell closed during lid-run)")
            } catch {
                // 尽力而为：失败不影响“系统不休眠”核心行为。
                AppLog.power.error("displaySleepNow failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// 读取内置盖子是否物理闭合（IOPMrootDomain 的 AppleClamshellState）。
    /// 台式机 / 无此键时返回 false —— 绝不在开盖或无盖状态下强制熄屏。
    private static func isClamshellClosed() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        guard let value = IORegistryEntryCreateCFProperty(
            service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() else {
            return false
        }
        return (value as? Bool) ?? false
    }

    /// 是否有外接（非内建）显示器在线。有则不强制熄屏（保护经典 clamshell 用户）。
    private static func hasExternalDisplay() -> Bool {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return false }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return false }
        return ids.prefix(Int(count)).contains { CGDisplayIsBuiltin($0) == 0 }
    }

    private func enforceProtectionRules(trigger: String) {
        guard isActive, settings.lidRunEnabled, lidRunState == .running else { return }
        let decision = protectionDecision(for: powerSnapshot)
        guard !decision.allowed else { return }

        Task {
            let reason = decision.reason ?? "保护规则触发"
            settings.lidRunEnabled = false
            await disableLidRun(notify: false)
            notifications.send(title: "合盖运行已自动停用", body: reason, enabled: settings.notificationsEnabled)
            AppLog.power.info("Protection disabled lid run via \(trigger, privacy: .public): \(reason, privacy: .public)")
        }
    }

    private func protectionDecision(for snapshot: PowerSnapshot) -> ProtectionDecision {
        if settings.acOnlyProtection && !snapshot.isOnACPower {
            return ProtectionDecision(allowed: false, reason: "仅接入电源时允许合盖运行")
        }

        if settings.lowBatteryProtection,
           let batteryPercent = snapshot.batteryPercent,
           batteryPercent < 20 {
            return ProtectionDecision(allowed: false, reason: "电池低于 20%")
        }

        if settings.thermalProtection && snapshot.isThermalDangerous {
            return ProtectionDecision(allowed: false, reason: "温度过高")
        }

        return .allowed
    }

    private func updateStatusMessage() {
        if !isActive {
            statusMessage = "未激活"
            return
        }

        let durationText: String
        if let remainingSeconds {
            durationText = "剩余 \(Self.formatRemaining(remainingSeconds))"
        } else {
            durationText = "无限时长"
        }

        if settings.lidRunEnabled {
            statusMessage = "\(lidRunState.title) · \(durationText)"
        } else if settings.preventSystemSleep || settings.preventDisplaySleep {
            statusMessage = "防休眠中 · \(durationText)"
        } else {
            statusMessage = "已激活 · 未选择防睡眠项"
        }
    }

    static func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return "\(hours)小时\(minutes)分"
        }
        if minutes > 0 {
            return "\(minutes)分\(secs)秒"
        }
        return "\(secs)秒"
    }
}
