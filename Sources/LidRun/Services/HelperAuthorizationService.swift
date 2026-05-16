import AppKit
import Foundation
import LidRunShared
import ServiceManagement

@MainActor
final class HelperAuthorizationService: ObservableObject {
    @Published private(set) var status: HelperStatus = .unknown
    @Published private(set) var lastError: String?

    let client = HelperXPCClient()
    private let daemonPlistName = "\(LidRunConstants.helperLabel).plist"
    private var authorizationPollTask: Task<Void, Never>?

    private var daemonService: SMAppService {
        SMAppService.daemon(plistName: daemonPlistName)
    }

    private var legacyPlistURL: URL {
        URL(fileURLWithPath: "/Library/LaunchDaemons/\(daemonPlistName)")
    }

    func refreshStatus() async {
        status = .unknown
        if await client.ping() {
            do {
                let version = try await client.helperVersion()
                if version >= LidRunConstants.helperProtocolVersion {
                    status = .installed
                    lastError = nil
                } else {
                    status = .unavailable("helper 版本过旧")
                    lastError = "当前 helper 版本过旧，请重新授权安装。"
                }
            } catch {
                status = .unavailable("helper 版本过旧")
                lastError = "当前 helper 缺少新版协议，请重新授权安装。"
            }
        } else {
            updateStatusFromServiceManagement()
        }
    }

    func installOrRequestAuthorization() async {
        status = .installing
        lastError = nil

        let service = daemonService
        switch service.status {
        case .enabled:
            await refreshStatus()
            if status != .installed {
                status = .unavailable("helper 已批准，但 XPC 暂未响应")
                lastError = "helper 已批准，但 XPC 暂未响应。请重启 LidRun 或在系统设置中重新启用后台项目。"
            }
            return
        case .requiresApproval:
            openSystemSettingsAuthorization()
            status = .requiresApproval
            startAuthorizationPolling()
            return
        case .notFound:
            if openDevelopmentInstallerIfAvailable() {
                status = .installing
                lastError = "当前运行包缺少可注册的内嵌 LaunchDaemon，已打开开发期授权安装器。"
                startAuthorizationPolling()
            } else {
                status = .unavailable("当前 App 包缺少内嵌 LaunchDaemon")
                lastError = "请先用 release 打包脚本生成带 helper 的 LidRun.app，或使用 script/install_helper_dev.sh 做本地授权。"
            }
            return
        case .notRegistered:
            break
        @unknown default:
            break
        }

        do {
            try service.register()
            AppLog.helper.info("Requested helper daemon registration")
            openSystemSettingsAuthorization()
            await refreshStatus()
            if status == .needsAuthorization {
                status = .requiresApproval
            }
            startAuthorizationPolling()
        } catch {
            lastError = error.localizedDescription
            AppLog.helper.error("Helper registration failed: \(error.localizedDescription, privacy: .public)")
            await refreshStatus()
            if status == .requiresApproval {
                openSystemSettingsAuthorization()
                startAuthorizationPolling()
            } else if status != .installed {
                if openDevelopmentInstallerIfAvailable() {
                    status = .installing
                    lastError = "正式注册失败：\(error.localizedDescription)。已打开开发期 helper 授权安装器。"
                    startAuthorizationPolling()
                } else {
                    status = .unavailable(error.localizedDescription)
                }
            }
        }
    }

    func uninstallHelperRegistration() {
        do {
            try daemonService.unregister()
            status = .needsAuthorization
        } catch {
            status = .unavailable(error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    func recordError(_ message: String) {
        lastError = message
    }

    func openSystemSettingsAuthorization() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func updateStatusFromServiceManagement() {
        switch daemonService.status {
        case .enabled:
            status = .unavailable("helper 已批准但未响应")
            lastError = "helper 已被系统批准，但当前 XPC 连接未响应。"
        case .requiresApproval:
            status = .requiresApproval
        case .notRegistered:
            updateStatusFromLegacyHelperIfPresent(defaultStatus: .needsAuthorization)
        case .notFound:
            updateStatusFromLegacyHelperIfPresent(defaultStatus: .unavailable("缺少 helper"))
        @unknown default:
            status = .needsAuthorization
        }
    }

    private func updateStatusFromLegacyHelperIfPresent(defaultStatus: HelperStatus) {
        guard FileManager.default.fileExists(atPath: legacyPlistURL.path) else {
            status = defaultStatus
            return
        }

        switch SMAppService.statusForLegacyPlist(at: legacyPlistURL) {
        case .enabled:
            status = .unavailable("本地 helper 未响应")
            lastError = "检测到 /Library/LaunchDaemons 中的开发期 helper，但 XPC 未响应。"
        case .requiresApproval:
            status = .requiresApproval
        case .notRegistered, .notFound:
            status = .needsAuthorization
        @unknown default:
            status = defaultStatus
        }
    }

    private func startAuthorizationPolling() {
        authorizationPollTask?.cancel()
        authorizationPollTask = Task { [weak self] in
            for _ in 0..<30 {
                guard let self, !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await self.refreshStatus()
                if self.status == .installed {
                    return
                }
            }
        }
    }

    private func openDevelopmentInstallerIfAvailable() -> Bool {
        let bundleURL = Bundle.main.bundleURL
        let rootCandidate = bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("script/install_helper_dev.command")

        guard FileManager.default.isExecutableFile(atPath: rootCandidate.path) else {
            return false
        }

        NSWorkspace.shared.open(rootCandidate)
        return true
    }
}
