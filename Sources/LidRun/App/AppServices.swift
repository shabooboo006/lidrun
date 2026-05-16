import Foundation

@MainActor
final class AppServices {
    static let shared = AppServices()

    let settings: AppSettings
    let helperAuthorization: HelperAuthorizationService
    let state: AppState

    private init() {
        settings = AppSettings()
        helperAuthorization = HelperAuthorizationService()
        state = AppState(settings: settings, helperAuthorization: helperAuthorization)
    }
}
