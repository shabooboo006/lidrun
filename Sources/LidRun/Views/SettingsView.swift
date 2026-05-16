import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var helper: HelperAuthorizationService

    var body: some View {
        Form {
            Section("系统授权") {
                LabeledContent("合盖运行 helper", value: helper.status.title)
                if helper.status != .installed {
                    Button(helper.status == .requiresApproval ? "打开系统设置批准" : "注册并授权 helper") {
                        if helper.status == .requiresApproval {
                            helper.openSystemSettingsAuthorization()
                        } else {
                            state.requestHelperAuthorization()
                        }
                    }
                    Button("重新检测 helper") {
                        Task { await helper.refreshStatus() }
                    }
                }
                if let error = helper.lastError, !error.isEmpty {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("合盖运行") {
                Toggle("默认启用合盖运行", isOn: Binding(
                    get: { settings.lidRunEnabled },
                    set: { state.setLidRunEnabled($0) }
                ))
                Toggle("仅接入电源时允许", isOn: $settings.acOnlyProtection)
                Toggle("电池低于 20% 自动停用", isOn: $settings.lowBatteryProtection)
                Toggle("温度过高时自动停用", isOn: $settings.thermalProtection)
            }

            Section("防休眠") {
                Toggle("防止系统空闲睡眠", isOn: Binding(
                    get: { settings.preventSystemSleep },
                    set: {
                        settings.preventSystemSleep = $0
                        state.updateSleepAssertions()
                    }
                ))
                Toggle("防止显示器空闲睡眠", isOn: Binding(
                    get: { settings.preventDisplaySleep },
                    set: {
                        settings.preventDisplaySleep = $0
                        state.updateSleepAssertions()
                    }
                ))
            }

            Section("启动与控制") {
                Toggle("登录时启动", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                ))
                Toggle("启动后自动激活", isOn: $settings.activateOnLaunch)
                Toggle("全局快捷键 ⌃⌥⌘L", isOn: Binding(
                    get: { settings.globalHotKeyEnabled },
                    set: {
                        settings.globalHotKeyEnabled = $0
                        state.configureHotKey()
                    }
                ))
                Toggle("通知提醒", isOn: $settings.notificationsEnabled)
                Toggle("彩色菜单栏图标", isOn: $settings.coloredIcon)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 420)
        .padding()
    }
}
