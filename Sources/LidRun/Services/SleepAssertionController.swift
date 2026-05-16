import Foundation
import IOKit.pwr_mgt

final class SleepAssertionController {
    private var systemAssertionID = IOPMAssertionID(0)
    private var displayAssertionID = IOPMAssertionID(0)
    private(set) var hasSystemAssertion = false
    private(set) var hasDisplayAssertion = false

    func update(preventSystemSleep: Bool, preventDisplaySleep: Bool) {
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
    }

    func releaseAll() {
        releaseSystemAssertion()
        releaseDisplayAssertion()
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
}
