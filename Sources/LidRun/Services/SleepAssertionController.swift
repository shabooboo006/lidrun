import Foundation
import IOKit.pwr_mgt

final class SleepAssertionController {
    private var systemAssertionID = IOPMAssertionID(0)
    private var displayAssertionID = IOPMAssertionID(0)
    private var screenLockAssertionID = IOPMAssertionID(0)
    private(set) var hasSystemAssertion = false
    private(set) var hasDisplayAssertion = false
    private(set) var hasScreenLockAssertion = false

    func update(preventSystemSleep: Bool, preventDisplaySleep: Bool, preventScreenLock: Bool) {
        if preventSystemSleep {
            createSystemAssertionIfNeeded()
        } else {
            releaseSystemAssertion()
        }

        if preventDisplaySleep {
            createDisplayAssertionIfNeeded()
        } else {
            releaseDisplayAssertion()
        }

        if preventScreenLock {
            createScreenLockAssertionIfNeeded()
        } else {
            releaseScreenLockAssertion()
        }
    }

    func releaseAll() {
        releaseSystemAssertion()
        releaseDisplayAssertion()
        releaseScreenLockAssertion()
    }

    private func createSystemAssertionIfNeeded() {
        guard !hasSystemAssertion else { return }

        let reason = "LidRun 正在防止系统空闲睡眠" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &systemAssertionID
        )

        if result == kIOReturnSuccess {
            hasSystemAssertion = true
            AppLog.power.info("Created NoIdleSleep assertion")
        } else {
            AppLog.power.error("Failed to create NoIdleSleep assertion: \(result, privacy: .public)")
        }
    }

    private func createDisplayAssertionIfNeeded() {
        guard !hasDisplayAssertion else { return }

        let reason = "LidRun 正在防止显示器空闲睡眠" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &displayAssertionID
        )

        if result == kIOReturnSuccess {
            hasDisplayAssertion = true
            AppLog.power.info("Created NoDisplaySleep assertion")
        } else {
            AppLog.power.error("Failed to create NoDisplaySleep assertion: \(result, privacy: .public)")
        }
    }

    // PreventUserIdleDisplaySleep：按住后用户空闲计时器无法到达显示器睡眠阈值，
    // 而屏保与空闲锁屏都是该计时器的下游，因此都不会触发；屏幕保持点亮。
    // 纯 IOKit，不经 helper，不修改任何系统安全设置。
    private func createScreenLockAssertionIfNeeded() {
        guard !hasScreenLockAssertion else { return }

        let reason = "LidRun 正在防止屏保与自动锁屏" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &screenLockAssertionID
        )

        if result == kIOReturnSuccess {
            hasScreenLockAssertion = true
            AppLog.power.info("Created PreventUserIdleDisplaySleep assertion (no screensaver/lock)")
        } else {
            AppLog.power.error("Failed to create PreventUserIdleDisplaySleep assertion: \(result, privacy: .public)")
        }
    }

    private func releaseSystemAssertion() {
        guard hasSystemAssertion else { return }
        IOPMAssertionRelease(systemAssertionID)
        systemAssertionID = 0
        hasSystemAssertion = false
        AppLog.power.info("Released NoIdleSleep assertion")
    }

    private func releaseDisplayAssertion() {
        guard hasDisplayAssertion else { return }
        IOPMAssertionRelease(displayAssertionID)
        displayAssertionID = 0
        hasDisplayAssertion = false
        AppLog.power.info("Released NoDisplaySleep assertion")
    }

    private func releaseScreenLockAssertion() {
        guard hasScreenLockAssertion else { return }
        IOPMAssertionRelease(screenLockAssertionID)
        screenLockAssertionID = 0
        hasScreenLockAssertion = false
        AppLog.power.info("Released PreventUserIdleDisplaySleep assertion")
    }
}
