import Foundation

@objc(LRLidRunHelperProtocol)
public protocol LidRunHelperProtocol {
    func ping(withReply reply: @escaping (Bool) -> Void)
    func helperVersion(withReply reply: @escaping (NSNumber) -> Void)
    func readDisableSleep(withReply reply: @escaping (NSNumber?, NSString?) -> Void)
    func setDisableSleep(_ enabled: Bool, withReply reply: @escaping (Bool, NSString?) -> Void)
    func restoreDisableSleep(_ value: NSNumber, withReply reply: @escaping (Bool, NSString?) -> Void)
}
