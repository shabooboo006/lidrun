import Foundation

public enum LidRunConstants {
    public static let appName = "LidRun"
    public static let bundleIdentifier = "com.xiachy.LidRun"
    public static let helperLabel = "com.xiachy.LidRun.Helper"
    public static let helperMachServiceName = "com.xiachy.LidRun.Helper"
    public static let helperExecutableName = "LidRunHelper"
    public static let helperProtocolVersion = 2
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
