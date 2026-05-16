import SwiftUI

@main
struct LidRunApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(AppServices.shared.state)
                .environmentObject(AppServices.shared.settings)
                .environmentObject(AppServices.shared.helperAuthorization)
        }
    }
}
