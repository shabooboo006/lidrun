import SwiftUI

struct LidRunPopoverView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var helper: HelperAuthorizationService

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 14)

            Divider()

            ScrollView(showsIndicators: true) {
                VStack(spacing: 14) {
                    LidRunPrimaryView()
                    DurationGridView()
                    AssertionSectionView()
                    ProtectionSectionView()
                    SettingsSectionView()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }

            Divider()

            FooterView()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 360, height: 600)
        .background(.regularMaterial)
        .font(.system(.body, design: .default))
    }
}

private struct HeaderView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LidRun")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)

                Text(state.statusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(state.isActive ? .blue : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 10)

            Toggle("", isOn: Binding(
                get: { state.isActive },
                set: { newValue in Task { await state.setActive(newValue) } }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.large)
        }
    }
}

private struct LidRunPrimaryView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var helper: HelperAuthorizationService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.blue.opacity(0.12))
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text("合盖运行")
                            .font(.system(size: 16, weight: .semibold))
                        HelperBadge(status: helper.status, lidState: state.lidRunState)
                    }

                    Text("合盖后内置屏幕关闭，长时间任务继续运行")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { settings.lidRunEnabled },
                    set: { state.setLidRunEnabled($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }

            if shouldShowHelperPanel {
                VStack(alignment: .leading, spacing: 8) {
                    Text(helperMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Button {
                            if helper.status == .installed {
                                Task { await state.setActive(true) }
                            } else if helper.status == .requiresApproval {
                                helper.openSystemSettingsAuthorization()
                            } else {
                                state.requestHelperAuthorization()
                            }
                        } label: {
                            Label(helperActionTitle, systemImage: helperActionIcon)
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 32)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .disabled(helper.status == .installing)

                        Button {
                            Task { await helper.refreshStatus() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 34, height: 32)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .help("重新检测 helper 状态")
                    }
                }
            }
        }
        .sectionSurface()
    }

    private var helperActionTitle: String {
        switch helper.status {
        case .installed:
            return "重试合盖运行"
        case .requiresApproval:
            return "打开系统设置批准"
        case .installing:
            return "正在授权"
        case .unavailable:
            return "重新注册 helper"
        default:
            return "注册并授权 helper"
        }
    }

    private var helperActionIcon: String {
        switch helper.status {
        case .installed:
            return "arrow.clockwise"
        case .requiresApproval:
            return "gearshape"
        case .installing:
            return "hourglass"
        default:
            return "lock.open"
        }
    }

    private var helperMessage: String {
        if let message = helper.lastError, !message.isEmpty {
            return message
        }

        switch helper.status {
        case .requiresApproval:
            return "已提交后台 helper 注册，请在系统设置的“登录项与后台项目”中允许 LidRun。"
        case .needsAuthorization:
            return "合盖运行需要 privileged helper 修改系统 disablesleep；普通防休眠仍可使用。"
        case .installing:
            return "正在等待 macOS 授权结果，批准后会自动重新检测。"
        case .unavailable:
            return "helper 当前不可用，请重新注册或使用正式签名包安装。"
        default:
            return "合盖运行需要系统授权。"
        }
    }

    private var shouldShowHelperPanel: Bool {
        if helper.status != .installed { return true }
        if let message = helper.lastError, !message.isEmpty { return true }
        if case .blocked = state.lidRunState { return true }
        return false
    }
}

private struct HelperBadge: View {
    var status: HelperStatus
    var lidState: LidRunState

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var title: String {
        if lidState == .running { return "运行中" }
        if case .blocked(let reason) = lidState { return reason }
        return status.title
    }

    private var color: Color {
        if case .blocked = lidState { return .orange }
        if case .unavailable = status { return .red }
        if lidState == .running || status == .installed { return .blue }
        if status == .requiresApproval || status == .needsAuthorization { return .orange }
        return .secondary
    }
}

private struct DurationGridView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: AppSettings

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("持续时间")

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(DurationOption.allCases) { option in
                    Button {
                        state.setDuration(option)
                    } label: {
                        Text(option.title)
                            .font(.system(size: option == .custom ? 12 : 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(settings.selectedDuration == option ? Color.blue : Color.secondary.opacity(0.12), in: Capsule())
                            .foregroundStyle(settings.selectedDuration == option ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .help(option.detail)
                }
            }

            if settings.selectedDuration == .custom {
                HStack(spacing: 10) {
                    Text("自定义")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Stepper("\(settings.customMinutes) 分钟", value: Binding(
                        get: { settings.customMinutes },
                        set: { state.setCustomMinutes($0) }
                    ), in: 1...1440)
                    .labelsHidden()
                    Text("\(settings.customMinutes) 分钟")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 64, alignment: .trailing)
                }
            }
        }
        .sectionSurface()
    }
}

private struct AssertionSectionView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle("防休眠")

            SettingsToggleRow(
                icon: "moon.zzz",
                title: "防止系统空闲睡眠",
                subtitle: "允许屏幕休眠，任务继续执行",
                isOn: Binding(
                    get: { settings.preventSystemSleep },
                    set: {
                        settings.preventSystemSleep = $0
                        state.updateSleepAssertions()
                    }
                )
            )

            SettingsToggleRow(
                icon: "display",
                title: "防止显示器空闲睡眠",
                subtitle: "等同 Caffeinated 的屏幕保持点亮",
                isOn: Binding(
                    get: { settings.preventDisplaySleep },
                    set: {
                        settings.preventDisplaySleep = $0
                        state.updateSleepAssertions()
                    }
                )
            )
        }
        .sectionSurface()
    }
}

private struct ProtectionSectionView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle("保护规则")

            SettingsToggleRow(
                icon: "powerplug",
                title: "仅接入电源时允许",
                subtitle: state.powerSnapshot.powerTitle,
                isOn: Binding(
                    get: { settings.acOnlyProtection },
                    set: { settings.acOnlyProtection = $0 }
                )
            )

            SettingsToggleRow(
                icon: "battery.25",
                title: "电池低于 20% 停用",
                subtitle: batterySubtitle,
                isOn: Binding(
                    get: { settings.lowBatteryProtection },
                    set: { settings.lowBatteryProtection = $0 }
                )
            )

            SettingsToggleRow(
                icon: "thermometer.high",
                title: "温度过高时停用",
                subtitle: state.powerSnapshot.thermalTitle,
                isOn: Binding(
                    get: { settings.thermalProtection },
                    set: { settings.thermalProtection = $0 }
                )
            )
        }
        .sectionSurface()
    }

    private var batterySubtitle: String {
        if let value = state.powerSnapshot.batteryPercent {
            return "当前 \(value)%"
        }
        return "未检测到电池"
    }
}

private struct SettingsSectionView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle("设置")

            SettingsToggleRow(
                icon: "arrow.clockwise",
                title: "登录时启动",
                subtitle: "随 macOS 自动启动",
                isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                )
            )

            SettingsToggleRow(
                icon: "bolt",
                title: "启动后自动激活",
                subtitle: "打开 LidRun 后立即启用",
                isOn: Binding(
                    get: { settings.activateOnLaunch },
                    set: { settings.activateOnLaunch = $0 }
                )
            )

            SettingsToggleRow(
                icon: "cursorarrow.click",
                title: "左键点击快速切换",
                subtitle: "右键仍打开弹出层",
                isOn: Binding(
                    get: { settings.quickToggleClick },
                    set: { settings.quickToggleClick = $0 }
                )
            )

            SettingsToggleRow(
                icon: "keyboard",
                title: "全局快捷键",
                subtitle: "⌃⌥⌘L",
                isOn: Binding(
                    get: { settings.globalHotKeyEnabled },
                    set: {
                        settings.globalHotKeyEnabled = $0
                        state.configureHotKey()
                    }
                )
            )

            SettingsToggleRow(
                icon: "bell",
                title: "通知提醒",
                subtitle: "启停和异常保护提醒",
                isOn: Binding(
                    get: { settings.notificationsEnabled },
                    set: { settings.notificationsEnabled = $0 }
                )
            )

            SettingsToggleRow(
                icon: "paintpalette",
                title: "彩色菜单栏图标",
                subtitle: "激活时使用系统蓝",
                isOn: Binding(
                    get: { settings.coloredIcon },
                    set: { settings.coloredIcon = $0 }
                )
            )
        }
        .sectionSurface()
    }
}

private struct FooterView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("当前状态")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(state.statusMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }

            Spacer()

            Button("高级设置…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .buttonStyle(.borderless)

            Button("关于") {
                state.showAbout()
            }
            .buttonStyle(.borderless)

            Button("退出") {
                state.quit()
            }
            .buttonStyle(.borderless)
        }
    }
}

private struct SectionTitle: View {
    private let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 2)
    }
}

private struct SettingsToggleRow: View {
    var icon: String
    var title: String
    var subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.12))
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 6)
    }
}

private extension View {
    func sectionSurface() -> some View {
        self
            .padding(12)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
