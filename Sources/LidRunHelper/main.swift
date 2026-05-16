import Foundation
import LidRunShared
import os
import Security

private let logger = Logger(subsystem: LidRunConstants.bundleIdentifier, category: "helper")

final class HelperDelegate: NSObject, NSXPCListenerDelegate {
    private let service = HelperService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        guard isClientTrusted(newConnection) else {
            logger.error("Rejected XPC connection: client code requirement not satisfied")
            return false
        }
        newConnection.exportedInterface = NSXPCInterface(with: LidRunHelperProtocol.self)
        newConnection.exportedObject = service
        newConnection.resume()
        logger.info("Accepted helper XPC connection")
        return true
    }

    /// 用连接进程的 pid 取得客户端 SecCode，校验其代码签名满足 clientCodeRequirement。
    /// （NSXPCConnection.auditToken 在当前 SDK 未桥接到 Swift，故用 pid 方案。）
    private func isClientTrusted(_ connection: NSXPCConnection) -> Bool {
        let attributes = [kSecGuestAttributePid as String: connection.processIdentifier] as CFDictionary

        var code: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess,
              let code else {
            return false
        }

        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(
            LidRunConstants.clientCodeRequirement as CFString, [], &requirement
        ) == errSecSuccess, let requirement else {
            return false
        }

        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }
}

let listener = NSXPCListener(machServiceName: LidRunConstants.helperMachServiceName)
let delegate = HelperDelegate()
listener.delegate = delegate
listener.resume()
logger.info("LidRun helper started")
RunLoop.main.run()
