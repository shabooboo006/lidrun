import Foundation

@objc(LRLidRunHelperProtocol)
public protocol LidRunHelperProtocol {
    func ping(withReply reply: @escaping (Bool) -> Void)
    func helperVersion(withReply reply: @escaping (NSNumber) -> Void)
    func readDisableSleep(withReply reply: @escaping (NSNumber?, NSString?) -> Void)
    func setDisableSleep(_ enabled: Bool, withReply reply: @escaping (Bool, NSString?) -> Void)
    func restoreDisableSleep(_ value: NSNumber, withReply reply: @escaping (Bool, NSString?) -> Void)
    /// 白名单操作：立即让显示器进入睡眠（合盖运行时省电用，等价 `pmset displaysleepnow`）。
    /// 不改变任何系统电源“设置”，是一次性动作；无参数，安全。
    func displaySleepNow(withReply reply: @escaping (Bool, NSString?) -> Void)
}
