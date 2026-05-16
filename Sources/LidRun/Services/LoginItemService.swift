import Foundation
import ServiceManagement

struct LoginItemService {
    func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    var statusTitle: String {
        switch SMAppService.mainApp.status {
        case .enabled: return "已启用"
        case .notRegistered: return "未启用"
        case .requiresApproval: return "需系统批准"
        case .notFound: return "未找到"
        @unknown default: return "未知"
        }
    }
}
