import Foundation

enum HelperStatus: Equatable {
    case unknown
    case installed
    case requiresApproval
    case needsAuthorization
    case installing
    case unavailable(String)

    var title: String {
        switch self {
        case .unknown: return "检测中"
        case .installed: return "已授权"
        case .requiresApproval: return "需批准"
        case .needsAuthorization: return "未安装"
        case .installing: return "授权中"
        case .unavailable: return "不可用"
        }
    }
}

enum LidRunState: Equatable {
    case off
    case enabling
    case running
    case blocked(String)
    case restoring

    var title: String {
        switch self {
        case .off: return "未启用"
        case .enabling: return "正在启用"
        case .running: return "合盖运行中"
        case let .blocked(reason): return reason
        case .restoring: return "正在恢复"
        }
    }
}

struct PowerSnapshot: Equatable {
    var isOnACPower: Bool
    var batteryPercent: Int?
    var thermalState: ProcessInfo.ThermalState

    static let unknown = PowerSnapshot(
        isOnACPower: false,
        batteryPercent: nil,
        thermalState: ProcessInfo.processInfo.thermalState
    )

    var powerTitle: String {
        if isOnACPower {
            return "已接入电源"
        }
        if let batteryPercent {
            return "电池 \(batteryPercent)%"
        }
        return "电池供电"
    }

    var thermalTitle: String {
        switch thermalState {
        case .nominal: return "温度正常"
        case .fair: return "温度偏高"
        case .serious: return "温度过高"
        case .critical: return "温度危险"
        @unknown default: return "温度未知"
        }
    }

    var isThermalDangerous: Bool {
        thermalState == .serious || thermalState == .critical
    }
}

struct ProtectionDecision {
    var allowed: Bool
    var reason: String?

    static let allowed = ProtectionDecision(allowed: true, reason: nil)
}
