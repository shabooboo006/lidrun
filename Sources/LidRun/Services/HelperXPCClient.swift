import Foundation
import LidRunShared

enum HelperClientError: LocalizedError {
    case connectionFailed(String)
    case operationFailed(String)
    case missingValue

    var errorDescription: String? {
        switch self {
        case let .connectionFailed(message): return message
        case let .operationFailed(message): return message
        case .missingValue: return "helper 未返回状态值"
        }
    }
}

final class HelperXPCClient: @unchecked Sendable {
    private let lock = NSLock()
    private var connection: NSXPCConnection?

    func invalidate() {
        let oldConnection: NSXPCConnection?
        lock.lock()
        oldConnection = connection
        connection = nil
        lock.unlock()
        oldConnection?.invalidate()
    }

    func ping() async -> Bool {
        await withCheckedContinuation { continuation in
            let once = Once()
            guard let proxy = proxy(onError: { error in
                AppLog.helper.error("XPC ping failed: \(error.localizedDescription, privacy: .public)")
                once.run { continuation.resume(returning: false) }
            }) else {
                continuation.resume(returning: false)
                return
            }

            proxy.ping { value in
                once.run { continuation.resume(returning: value) }
            }
        }
    }

    func helperVersion() async throws -> Int {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            let once = Once()
            guard let proxy = proxy(onError: { error in
                once.run {
                    continuation.resume(throwing: HelperClientError.connectionFailed(error.localizedDescription))
                }
            }) else {
                continuation.resume(throwing: HelperClientError.connectionFailed("无法连接 privileged helper"))
                return
            }

            proxy.helperVersion { value in
                once.run {
                    continuation.resume(returning: value.intValue)
                }
            }
        }
    }

    func readDisableSleep() async throws -> Int {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            let once = Once()
            guard let proxy = proxy(onError: { error in
                once.run {
                    continuation.resume(throwing: HelperClientError.connectionFailed(error.localizedDescription))
                }
            }) else {
                continuation.resume(throwing: HelperClientError.connectionFailed("无法连接 privileged helper"))
                return
            }

            proxy.readDisableSleep { value, error in
                once.run {
                    if let error {
                        continuation.resume(throwing: HelperClientError.operationFailed(error as String))
                    } else if let value {
                        continuation.resume(returning: value.intValue == 0 ? 0 : 1)
                    } else {
                        continuation.resume(throwing: HelperClientError.missingValue)
                    }
                }
            }
        }
    }

    func setDisableSleep(_ enabled: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = Once()
            guard let proxy = proxy(onError: { error in
                once.run {
                    continuation.resume(throwing: HelperClientError.connectionFailed(error.localizedDescription))
                }
            }) else {
                continuation.resume(throwing: HelperClientError.connectionFailed("无法连接 privileged helper"))
                return
            }

            proxy.setDisableSleep(enabled) { ok, error in
                once.run {
                    if ok {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: HelperClientError.operationFailed((error as String?) ?? "helper 设置失败"))
                    }
                }
            }
        }
    }

    func restoreDisableSleep(_ value: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = Once()
            guard let proxy = proxy(onError: { error in
                once.run {
                    continuation.resume(throwing: HelperClientError.connectionFailed(error.localizedDescription))
                }
            }) else {
                continuation.resume(throwing: HelperClientError.connectionFailed("无法连接 privileged helper"))
                return
            }

            proxy.restoreDisableSleep(NSNumber(value: value)) { ok, error in
                once.run {
                    if ok {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: HelperClientError.operationFailed((error as String?) ?? "helper 恢复失败"))
                    }
                }
            }
        }
    }

    private func proxy(onError: @escaping (Error) -> Void) -> LidRunHelperProtocol? {
        let connection = makeConnection()
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            AppLog.helper.error("XPC proxy error: \(error.localizedDescription, privacy: .public)")
            self.invalidate()
            onError(error)
        } as? LidRunHelperProtocol
        return proxy
    }

    private func makeConnection() -> NSXPCConnection {
        lock.lock()
        if let connection {
            lock.unlock()
            return connection
        }
        lock.unlock()

        let newConnection = NSXPCConnection(
            machServiceName: LidRunConstants.helperMachServiceName,
            options: .privileged
        )
        newConnection.remoteObjectInterface = NSXPCInterface(with: LidRunHelperProtocol.self)
        newConnection.invalidationHandler = { [weak self] in
            self?.clearConnection()
            AppLog.helper.info("XPC connection invalidated")
        }
        newConnection.interruptionHandler = {
            AppLog.helper.info("XPC connection interrupted")
        }
        newConnection.resume()
        lock.lock()
        connection = newConnection
        lock.unlock()
        return newConnection
    }

    private func clearConnection() {
        lock.lock()
        connection = nil
        lock.unlock()
    }
}

private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var didRun = false

    func run(_ body: () -> Void) {
        lock.lock()
        guard !didRun else {
            lock.unlock()
            return
        }
        didRun = true
        lock.unlock()
        body()
    }
}
