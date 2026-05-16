import Foundation
import LidRunShared
import os

final class HelperService: NSObject, LidRunHelperProtocol {
    private let pmset = PMSetController()
    private let logger = Logger(subsystem: LidRunConstants.bundleIdentifier, category: "helper.service")

    func ping(withReply reply: @escaping (Bool) -> Void) {
        reply(true)
    }

    func helperVersion(withReply reply: @escaping (NSNumber) -> Void) {
        reply(NSNumber(value: LidRunConstants.helperProtocolVersion))
    }

    func readDisableSleep(withReply reply: @escaping (NSNumber?, NSString?) -> Void) {
        do {
            let value = try pmset.readDisableSleep()
            logger.info("Read disablesleep=\(value, privacy: .public)")
            reply(NSNumber(value: value), nil)
        } catch {
            logger.error("Failed to read disablesleep: \(error.localizedDescription, privacy: .public)")
            reply(nil, error.localizedDescription as NSString)
        }
    }

    func setDisableSleep(_ enabled: Bool, withReply reply: @escaping (Bool, NSString?) -> Void) {
        do {
            try pmset.setDisableSleep(enabled)
            logger.info("Set disablesleep=\(enabled ? 1 : 0, privacy: .public)")
            reply(true, nil)
        } catch {
            logger.error("Failed to set disablesleep: \(error.localizedDescription, privacy: .public)")
            reply(false, error.localizedDescription as NSString)
        }
    }

    func restoreDisableSleep(_ value: NSNumber, withReply reply: @escaping (Bool, NSString?) -> Void) {
        do {
            let restoredValue = value.intValue == 0 ? 0 : 1
            try pmset.setDisableSleep(restoredValue == 1)
            logger.info("Restored disablesleep=\(restoredValue, privacy: .public)")
            reply(true, nil)
        } catch {
            logger.error("Failed to restore disablesleep: \(error.localizedDescription, privacy: .public)")
            reply(false, error.localizedDescription as NSString)
        }
    }
}
