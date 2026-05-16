# LidRun

LidRun 是原生 macOS 菜单栏应用，使用 Swift、SwiftUI、少量 AppKit、IOKit power assertions 和 privileged helper/XPC 实现。

## 运行

```bash
./script/build_and_run.sh --verify
```

脚本会构建 SwiftPM 目标，生成 `dist/LidRun.app`，并通过 Launch Services 启动菜单栏应用。

## 发布签名与公证

LidRun 的正式包需要 Developer ID 签名和 Apple notarization，因为合盖运行依赖内嵌的 privileged LaunchDaemon。

本地 release 构建：

```bash
./script/build_macos_release.sh
```

生成 zip / pkg / dmg：

```bash
./script/package_macos_release.sh
```

Developer ID 签名并提交公证：

```bash
NOTARYTOOL_PROFILE=CodeRelayNotary ./script/sign_and_notarize_macos_release.sh
```

脚本会自动从 keychain 查找 `Developer ID Application` 和 `Developer ID Installer` 证书；也可以通过环境变量显式指定：

```bash
APP_SIGN_IDENTITY="Developer ID Application: ..." \
INSTALLER_SIGN_IDENTITY="Developer ID Installer: ..." \
NOTARYTOOL_PROFILE=CodeRelayNotary \
./script/sign_and_notarize_macos_release.sh
```

正式包内的 helper 位于：

```text
LidRun.app/Contents/Library/LaunchDaemons/com.xiachy.LidRun.Helper
```

对应 plist 使用 `BundleProgram`，由 `SMAppService.daemon(plistName:)` 注册。首次启用合盖运行时，App 会打开 macOS “登录项与后台项目”设置页，用户批准后 helper 才会由系统启动。

## 功能边界

- 普通防休眠使用 IOKit assertion：`NoIdleSleep` 和 `NoDisplaySleep`。
- 合盖运行模式通过 privileged helper 执行白名单 `pmset` 操作：读取、启用、恢复 `disablesleep`。
- 主 App 只通过 XPC 调用 helper，不执行任意 shell 命令。
- helper 未安装或未授权时，界面显示“需授权”，普通防休眠功能仍可使用。

## 开发期 helper 安装

生产形态使用 `SMAppService.daemon(plistName:)` 注册 helper，要求完整签名、公证和内嵌的 launch daemon plist。开发调试时可以先构建，再运行：

```bash
./script/install_helper_dev.sh
```

该脚本需要管理员密码，会把 helper 安装到 `/Library/PrivilegedHelperTools/com.xiachy.LidRun.Helper` 并注册 `/Library/LaunchDaemons/com.xiachy.LidRun.Helper.plist`。

如果从 `dist/LidRun.app` 运行，授权按钮在检测到当前包缺少可注册的正式内嵌 daemon 时，也会尝试打开 `script/install_helper_dev.command`，便于本地验证。

## 验证合盖运行

启用合盖运行时，App 会先读取并保存原始 `disablesleep`，再通过 helper 设置 `pmset -a disablesleep 1`，随后立即反读确认系统值已经变为 `1`。如果反读不是 `1`，界面会显示失败原因，不会假装“合盖运行中”。

关闭、退出、断电、低电量或温度过高触发保护时，App 会尽量通过 helper 恢复保存的原始值。

## 关键文件

- `Sources/LidRun/App`: SwiftUI app lifecycle、AppKit status item、popover。
- `Sources/LidRun/Stores/AppState.swift`: 主状态机、倒计时、保护规则和恢复逻辑。
- `Sources/LidRun/Services`: IOKit assertion、XPC、登录项、通知、电源状态和快捷键。
- `Sources/LidRunHelper`: privileged helper，仅允许白名单 `pmset` 操作。
- `Sources/LidRunShared`: App 与 helper 共享的 XPC 协议和常量。
