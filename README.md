# LidRun

> 合上 MacBook 盖子，屏幕熄灭，但系统不休眠 —— 长时间任务继续跑。

LidRun 是一款原生 macOS 菜单栏应用（Swift / SwiftUI / AppKit / IOKit / XPC + privileged helper），用来替代 Caffeinated。

它覆盖常规防空闲休眠（IOKit power assertions），但**核心差异**是：

> **合上盖子（甚至拔掉电源、不接外接显示器、内置屏幕熄灭）后，系统不进入睡眠，正在运行的软件继续执行。**

普通 `caffeinate -d` 或 `NoDisplaySleep` 无法解决合盖睡眠，LidRun 通过一个最小白名单的 privileged helper 执行 `pmset disablesleep`，并配合 IOKit assertion 实现。

## 下载安装

到 [Releases](https://github.com/shabooboo006/lidrun/releases) 下载最新版：

1. 下载 `LidRun-<version>.dmg`，打开，将 **LidRun** 拖入「应用程序」。
2. LidRun 是菜单栏应用（没有 Dock 图标），启动后在顶栏找它的图标。
3. 开启「合盖运行」时，按提示在 **系统设置 ▸ 通用 ▸ 登录项** 里批准 LidRun 的后台 helper，之后合盖运行才可用。

发布包经 Developer ID 签名 + Apple 公证（notarized），正常双击即可打开，无需绕过 Gatekeeper。

> ⚠️ 当前为 **pre-release**：helper 注册/授权流程已在 macOS 26 真机验证可用；核心的「合盖 + 拔电 + 无外接显示器物理不休眠」端到端行为仍建议你按发布说明自行验证后再长期依赖。欢迎反馈。

## 功能边界

- 常规防休眠使用 IOKit assertion：`NoIdleSleep` / `NoDisplaySleep`。
- 合盖运行通过 privileged helper 执行白名单 `pmset` 操作：读取、启用、恢复 `disablesleep`，以及 `displaysleepnow`。
- 合盖 + 无外接显示器时，LidRun 主动让屏幕熄灭省电（`pmset displaysleepnow`），同时靠 IOKit `NoIdleSleep` 保持系统不休眠；严格只在盖子物理闭合且无外接显示器时触发，绝不弄黑你正在用的屏幕。
- 主 App 只通过 XPC 调用 helper，App↔helper 双向校验代码签名（同 Team），不执行任意 shell。
- helper 未安装/未授权时，界面显示「需授权」，普通防休眠仍可用。
- 保护规则：`仅接入电源时允许` 默认**关闭**（电池下也能合盖）；`电池<20%`、`温度过高` 默认开启作为安全兜底，可在界面调整。
- 关闭、退出、断电、低电量、过热或崩溃恢复时，尽量把 `disablesleep` 恢复成开启前保存的原值，不会无条件置 0。

## 从源码构建

需要 macOS 14+ 和 Swift 6 工具链。

```bash
swift build                  # 编译（唯一的编译/检查 gate；无单元测试）
./script/build_and_run.sh    # 组装 dist/LidRun.app（ad-hoc）并启动菜单栏 App
```

测试 privileged helper / SMAppService 需要 Developer ID 签名包从稳定位置运行：

```bash
./script/dev_signed_run.sh   # 构建 Developer ID 签名包，安装到 /Applications，启动
```

清理与签名包冲突的旧版 ad-hoc helper（需管理员，仅在需要时）：

```bash
sudo ./script/install_helper_dev.sh --cleanup
```

## 发布

正式发布的版本规范、签名/公证、release notes 结构与发布命令，见 `CLAUDE.md` 的 **Release process（规范发布）** 一节。一行构建签名公证包：

```bash
VERSION=<x.y.z> PACKAGE_FORMATS="zip dmg" \
NOTARYTOOL_PROFILE=CodeRelayNotary \
./script/sign_and_notarize_macos_release.sh
```

## 仓库结构

- `Sources/LidRun/App` — SwiftUI 生命周期、AppKit status item、popover。
- `Sources/LidRun/Stores/AppState.swift` — 主状态机、倒计时、保护规则、恢复逻辑。
- `Sources/LidRun/Services` — IOKit assertion、XPC、登录项、通知、电源状态、快捷键。
- `Sources/LidRun/Support` — 共享字形、状态图标、日志。
- `Sources/LidRunHelper` — privileged helper，仅白名单 `pmset` 操作。
- `Sources/LidRunShared` — App 与 helper 共享的 XPC 协议、常量、代码签名 requirement。
- `AGENTS.md` — 产品范围、电源行为、安全边界、保护策略的中文权威说明（source of truth）。
- `CLAUDE.md` — 命令、跨文件架构、发布规范。

## License

[MIT](LICENSE) © 2026 Chunyu Xia
