import Foundation
import LidRunShared
import os

private let logger = Logger(subsystem: LidRunConstants.bundleIdentifier, category: "helper")

final class HelperDelegate: NSObject, NSXPCListenerDelegate {
    private let service = HelperService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: LidRunHelperProtocol.self)
        newConnection.exportedObject = service
        newConnection.resume()
        logger.info("Accepted helper XPC connection")
        return true
    }
}

let listener = NSXPCListener(machServiceName: LidRunConstants.helperMachServiceName)
let delegate = HelperDelegate()
listener.delegate = delegate
listener.resume()
logger.info("LidRun helper started")
RunLoop.main.run()
