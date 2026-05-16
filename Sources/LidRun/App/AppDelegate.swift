import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var isTerminating = false

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let state = AppServices.shared.state
        statusItemController = StatusItemController(state: state)
        state.start()
        AppLog.app.info("Application launched")
    }

    @MainActor
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTerminating else { return .terminateNow }
        isTerminating = true

        Task {
            await AppServices.shared.state.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }
}
