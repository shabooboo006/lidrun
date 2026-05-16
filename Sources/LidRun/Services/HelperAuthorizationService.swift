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

    /// 运行中的 App bundle 是否真的内嵌了 daemon plist。
    /// macOS 26 (Tahoe) 上未注册的内嵌 daemon，SMAppService 状态是 .notFound
    /// （而非旧系统的 .notRegistered），不能据此判定“缺少 helper”；
    /// 必须看 bundle 里 Contents/Library/LaunchDaemons/<plist> 是否真实存在。
    private var isDaemonEmbeddedInBundle: Bool {
        let url = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchDaemons", isDirectory: true)
            .appendingPathComponent(daemonPlistName)
        return FileManager.default.fileExists(atPath: url.path)
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
                status = .unavailable("已批准但 XPC 未通过校验")
                lastError = "helper 已被系统批准，但 XPC 未通过代码签名校验或未响应。请确认运行的是 Developer ID 签名包（script/dev_signed_run.sh），并清理旧版 helper（script/install_helper_dev.sh --cleanup）。"
            }
            return
        case .requiresApproval:
            openSystemSettingsAuthorization()
            status = .requiresApproval
            startAuthorizationPolling()
            return
        case .notFound, .notRegistered:
            // macOS 26 (Tahoe): a present-but-never-registered embedded daemon
            // reports .notFound (not .notRegistered). Only bail if the daemon is
            // genuinely not embedded in this bundle; otherwise fall through and
            // call register() so BTM creates a record and the approval flow starts.
            guard isDaemonEmbeddedInBundle else {
                status = .unavailable("当前 App 包缺少内嵌 LaunchDaemon")
                lastError = "当前运行的不是带内嵌 helper 的签名包（缺少 Contents/Library/LaunchDaemons/\(daemonPlistName)）。请从 Releases 安装已签名的 LidRun.app，或用 script/dev_signed_run.sh。"
                return
            }
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
                status = .unavailable(error.localizedDescription)
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
            if isDaemonEmbeddedInBundle {
                // Tahoe: embedded but not yet registered → registration available.
                status = .needsAuthorization
            } else {
                updateStatusFromLegacyHelperIfPresent(defaultStatus: .unavailable("缺少 helper"))
            }
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
            status = .unavailable("检测到旧版 helper")
            lastError = "检测到 /Library/LaunchDaemons 中的旧版（ad-hoc）helper，与签名包冲突。请运行 script/install_helper_dev.sh --cleanup 移除后重试。"
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


}
