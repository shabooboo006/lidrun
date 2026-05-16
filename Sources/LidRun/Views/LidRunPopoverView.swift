import SwiftUI

// MARK: - 字号字重四级层级（全局统一，苹果系统字体栈）

private enum LRType {
    static let wordmark = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let status = Font.system(size: 12, weight: .medium)
    static let section = Font.system(size: 11, weight: .semibold)
    static let rowTitle = Font.system(size: 13, weight: .semibold)
    static let rowSubtitle = Font.system(size: 11, weight: .regular)
    static let duration = Font.system(size: 14, weight: .semibold)
}

struct LidRunPopoverView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var helper: HelperAuthorizationService

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
                .padding(.horizontal, 16)
                .padding(.top, 15)
                .padding(.bottom, 12)
            Divider().opacity(0.6)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    LidRunPrimaryView()
                        .padding(.horizontal, 16)
                        .padding(.top, 13)
                        .padding(.bottom, 6)

                    SectionGroup(title: "持续时间") { DurationGridView() }
                    SectionGroup(title: "防休眠") { AssertionSectionView() }
                    SectionGroup(title: "保护规则") { ProtectionSectionView() }
                    SectionGroup(title: "设置") { SettingsSectionView() }
                }
                .padding(.bottom, 8)
            }

            Divider().opacity(0.6)
            FooterView()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 360, height: 600)
        .background(.regularMaterial)
    }
}

// MARK: - 通用容器：小节标题 + 细分隔线 + 间距（无灰盒子）

private struct SectionGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().opacity(0.6).padding(.horizontal, 16)
            Text(title)
                .font(LRType.section)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)
            content
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }
}

// MARK: - Header：图标 + 小号 SF Pro Rounded 字标锁定组

private struct HeaderView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    LidGlyphShape()
                        .fill(.primary)
                        .frame(width: 21, height: 16)
                    Text("LidRun")
                        .font(LRType.wordmark)
                        .foregroundStyle(.primary)
                }
                Text(state.statusMessage)
                    .font(LRType.status)
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

// MARK: - 合盖运行主行 + 内联 helper 提示

private struct LidRunPrimaryView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var helper: HelperAuthorizationService

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.14))
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Text("合盖运行").font(LRType.rowTitle)
                        HelperBadge(status: helper.status, lidState: state.lidRunState)
                    }
                    Text("合盖后内置屏幕关闭，任务继续运行")
                        .font(LRType.rowSubtitle)
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

            if shouldShowHelperNotice {
                HStack(alignment: .top, spacing: 8) {
                    Text(helperMessage)
                        .font(LRType.rowSubtitle)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    HStack(spacing: 6) {
                        Button(helperActionTitle) {
                            if helper.status == .installed {
                                Task { await state.setActive(true) }
                            } else if helper.status == .requiresApproval {
                                helper.openSystemSettingsAuthorization()
                            } else {
                                state.requestHelperAuthorization()
                            }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(helper.status == .installing)

                        Button {
                            Task { await helper.refreshStatus() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("重新检测 helper 状态")
                    }
                }
                .padding(.leading, 40)
            }
        }
    }

    private var helperActionTitle: String {
        switch helper.status {
        case .installed: return "重试"
        case .requiresApproval: return "打开系统设置"
        case .installing: return "授权中"
        case .unavailable: return "重新注册"
        default: return "注册并授权"
        }
    }

    private var helperMessage: String {
        if let message = helper.lastError, !message.isEmpty { return message }
        switch helper.status {
        case .requiresApproval: return "请在「系统设置 › 通用 › 登录项」中允许 LidRun。"
        case .needsAuthorization: return "合盖运行需要 helper 修改系统 disablesleep；普通防休眠仍可用。"
        case .installing: return "正在等待 macOS 授权结果。"
        case .unavailable: return "helper 当前不可用，请重新注册或用正式签名包安装。"
        default: return "合盖运行需要系统授权。"
        }
    }

    private var shouldShowHelperNotice: Bool {
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
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }

    private var title: String {
        if lidState == .running { return "运行中" }
        if case .blocked(let reason) = lidState { return reason }
        if status == .installed { return "可用" }
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

// MARK: - 持续时间

private struct DurationGridView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: AppSettings
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(DurationOption.allCases) { option in
                    Button {
                        state.setDuration(option)
                    } label: {
                        Text(option.title)
                            .font(option == .custom ? .system(size: 12, weight: .semibold) : LRType.duration)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(
                                settings.selectedDuration == option ? Color.blue : Color.secondary.opacity(0.13),
                                in: Capsule()
                            )
                            .foregroundStyle(settings.selectedDuration == option ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .help(option.detail)
                }
            }
            if settings.selectedDuration == .custom {
                HStack(spacing: 10) {
                    Text("自定义").font(LRType.rowSubtitle)
                    Spacer()
                    Stepper("\(settings.customMinutes) 分钟", value: Binding(
                        get: { settings.customMinutes },
                        set: { state.setCustomMinutes($0) }
                    ), in: 1...1440)
                    .labelsHidden()
                    Text("\(settings.customMinutes) 分钟")
                        .font(LRType.rowSubtitle)
                        .foregroundStyle(.secondary)
                        .frame(width: 64, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - 防休眠 / 保护规则 / 设置

private struct AssertionSectionView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(spacing: 2) {
            SettingsToggleRow(icon: "moon.zzz", title: "防止系统空闲睡眠", subtitle: "允许屏幕休眠，任务继续执行", isOn: Binding(
                get: { settings.preventSystemSleep },
                set: { settings.preventSystemSleep = $0; state.updateSleepAssertions() }
            ))
            SettingsToggleRow(icon: "display", title: "防止显示器空闲睡眠", subtitle: "屏幕保持点亮", isOn: Binding(
                get: { settings.preventDisplaySleep },
                set: { settings.preventDisplaySleep = $0; state.updateSleepAssertions() }
            ))
        }
    }
}

private struct ProtectionSectionView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 2) {
            SettingsToggleRow(icon: "powerplug", title: "仅接入电源时允许", subtitle: "默认关闭 · 电池下也可合盖", isOn: Binding(
                get: { settings.acOnlyProtection },
                set: { settings.acOnlyProtection = $0 }
            ))
            SettingsToggleRow(icon: "battery.25", title: "电池低于 20% 停用", subtitle: batterySubtitle, isOn: Binding(
                get: { settings.lowBatteryProtection },
                set: { settings.lowBatteryProtection = $0 }
            ))
            SettingsToggleRow(icon: "thermometer.high", title: "温度过高时停用", subtitle: state.powerSnapshot.thermalTitle, isOn: Binding(
                get: { settings.thermalProtection },
                set: { settings.thermalProtection = $0 }
            ))
        }
    }

    private var batterySubtitle: String {
        if let value = state.powerSnapshot.batteryPercent { return "当前 \(value)%" }
        return "未检测到电池"
    }
}

private struct SettingsSectionView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(spacing: 2) {
            SettingsToggleRow(icon: "arrow.clockwise", title: "登录时启动", subtitle: "随 macOS 自动启动", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { state.setLaunchAtLogin($0) }
            ))
            SettingsToggleRow(icon: "bolt", title: "启动后自动激活", subtitle: "打开 LidRun 后立即启用", isOn: Binding(
                get: { settings.activateOnLaunch },
                set: { settings.activateOnLaunch = $0 }
            ))
            SettingsToggleRow(icon: "cursorarrow.click", title: "左键点击快速切换", subtitle: "右键仍打开弹出层", isOn: Binding(
                get: { settings.quickToggleClick },
                set: { settings.quickToggleClick = $0 }
            ))
            SettingsToggleRow(icon: "keyboard", title: "全局快捷键", subtitle: "⌃⌥⌘L", isOn: Binding(
                get: { settings.globalHotKeyEnabled },
                set: { settings.globalHotKeyEnabled = $0; state.configureHotKey() }
            ))
            SettingsToggleRow(icon: "bell", title: "通知提醒", subtitle: "启停和异常保护提醒", isOn: Binding(
                get: { settings.notificationsEnabled },
                set: { settings.notificationsEnabled = $0 }
            ))
            SettingsToggleRow(icon: "paintpalette", title: "彩色菜单栏图标", subtitle: "激活时使用系统蓝", isOn: Binding(
                get: { settings.coloredIcon },
                set: { settings.coloredIcon = $0 }
            ))
        }
    }
}

private struct FooterView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Text("当前状态 ·").font(.system(size: 11)).foregroundStyle(.secondary)
                Text(state.statusMessage).font(.system(size: 12, weight: .semibold)).lineLimit(1)
            }
            Spacer()
            Button("设置") { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }
                .buttonStyle(.borderless)
            Button("关于") { state.showAbout() }
                .buttonStyle(.borderless)
            Button("退出") { state.quit() }
                .buttonStyle(.borderless)
        }
        .font(.system(size: 12))
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
                Circle().fill(Color.secondary.opacity(0.13))
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(LRType.rowTitle).lineLimit(1)
                Text(subtitle).font(LRType.rowSubtitle).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 5)
    }
}
