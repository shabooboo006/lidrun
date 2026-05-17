import Foundation

public enum LidRunConstants {
    public static let appName = "LidRun"
    public static let bundleIdentifier = "com.xiachy.LidRun"
    public static let helperLabel = "com.xiachy.LidRun.Helper"
    public static let helperMachServiceName = "com.xiachy.LidRun.Helper"
    public static let helperExecutableName = "LidRunHelper"
    // 3: 新增 displaySleepNow 白名单能力（合盖熄屏省电）。提升版本号让旧
    // helper 被识别为过旧，触发重新注册以获得新能力。
    public static let helperProtocolVersion = 3
    public static let minimumSystemVersion = "14.0"

    /// Developer ID 团队标识（出现在证书 subject.OU）。
    public static let teamIdentifier = "XKR29B92B2"

    /// helper 校验来连客户端（主 App）用的代码签名 requirement。
    public static let clientCodeRequirement =
        "anchor apple generic and identifier \"\(bundleIdentifier)\" and certificate leaf[subject.OU] = \"\(teamIdentifier)\""

    /// 主 App 钉住 helper 端点用的代码签名 requirement。
    public static let helperCodeRequirement =
        "anchor apple generic and identifier \"\(helperLabel)\" and certificate leaf[subject.OU] = \"\(teamIdentifier)\""
}
