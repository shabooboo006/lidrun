import Foundation

enum DurationOption: String, CaseIterable, Identifiable {
    case unlimited
    case minutes15
    case minutes30
    case minutes45
    case hour1
    case hour4
    case hour8
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unlimited: return "∞"
        case .minutes15: return "15"
        case .minutes30: return "30"
        case .minutes45: return "45"
        case .hour1: return "1h"
        case .hour4: return "4h"
        case .hour8: return "8h"
        case .custom: return "自定义"
        }
    }

    var detail: String {
        switch self {
        case .unlimited: return "无限时长"
        case .minutes15: return "15 分钟"
        case .minutes30: return "30 分钟"
        case .minutes45: return "45 分钟"
        case .hour1: return "1 小时"
        case .hour4: return "4 小时"
        case .hour8: return "8 小时"
        case .custom: return "自定义"
        }
    }

    func seconds(customMinutes: Int) -> TimeInterval? {
        switch self {
        case .unlimited:
            return nil
        case .minutes15:
            return 15 * 60
        case .minutes30:
            return 30 * 60
        case .minutes45:
            return 45 * 60
        case .hour1:
            return 60 * 60
        case .hour4:
            return 4 * 60 * 60
        case .hour8:
            return 8 * 60 * 60
        case .custom:
            return TimeInterval(max(1, customMinutes) * 60)
        }
    }
}
