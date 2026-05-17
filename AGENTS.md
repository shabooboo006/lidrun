# AGENTS.md

本文件是 LidRun 仓库的开发代理工作说明。适用于整个仓库。

## 项目定位

LidRun 是一款原生 macOS 菜单栏应用，用来替代 Caffeinated。它必须完整覆盖常规防休眠能力，但核心差异不是“防止屏幕睡眠”，而是：

**MacBook 合上盖子后，内置屏幕可以关闭，但系统不要进入待机或睡眠，长时间任务继续运行。**

开发时始终把“合盖运行”放在第一优先级。普通 `caffeinate -d` 或单纯 `NoDisplaySleep` 不能解决合盖睡眠问题，不要把它们当作核心方案。

## 技术栈硬约束

- 必须使用 Swift、SwiftUI、少量 AppKit、IOKit、XPC、privileged helper。
- 不允许引入 Electron、Tauri、Flutter、网页壳、Catalyst 或 WebView dashboard。
- App 必须保持原生、轻量、稳定，面向 macOS 原生电源管理能力。
- 当前工程使用 Swift Package，最低平台为 macOS 14。

## 仓库结构

- `Sources/LidRun/App`: SwiftUI app lifecycle、AppKit `NSStatusItem`、`NSPopover`。
- `Sources/LidRun/Views`: 菜单栏 popover 的 SwiftUI 界面。
- `Sources/LidRun/Stores`: 用户设置和主状态机。
- `Sources/LidRun/Services`: IOKit assertion、XPC、登录项、通知、电源状态、全局快捷键。
- `Sources/LidRun/Support`: 日志、状态图标等支持代码。
- `Sources/LidRunHelper`: privileged helper，只处理白名单系统电源操作。
- `Sources/LidRunShared`: App 与 helper 共享的 XPC 协议、常量和类型。
- `script/`: 构建、运行、开发期 helper 安装脚本。

## 架构原则

- 主 App 使用 SwiftUI 管理状态和界面。
- 菜单栏入口必须使用 AppKit `NSStatusItem`。
- popover 必须使用 `NSPopover`，SwiftUI 内容通过 `NSHostingController` 承载。
- 不做普通主窗口，不做大屏 dashboard，不做营销页。
- 普通防空闲睡眠使用 IOKit power assertions。
- 合盖运行相关的 `pmset disablesleep` 只能通过 privileged helper 执行。
- App 与 helper 之间通过 XPC 协议通信，协议定义放在 `LidRunShared`。
- 用户设置使用 `UserDefaults` / `AppStorage` 风格的持久化，状态模型使用 `ObservableObject` 和 Swift Concurrency。

## 电源管理规则

普通 Caffeinated 功能：

- 防止系统空闲睡眠使用 `kIOPMAssertionTypeNoIdleSleep`。
- 防止显示器空闲睡眠使用 `kIOPMAssertionTypeNoDisplaySleep`。
- 防止屏保与自动锁屏使用 `kIOPMAssertionTypePreventUserIdleDisplaySleep`：屏幕保持点亮，
  既不进入屏保也不空闲锁屏。纯 IOKit、不经 helper、不修改任何系统安全设置，因此不与
  「绝不绕过锁屏」边界冲突（是保持屏幕点亮，而非绕过熄屏后的锁屏）。
- 必须支持允许屏幕休眠但阻止系统睡眠。
- 必须支持无限时长、15/30/45 分钟、1/4/8 小时、自定义时长。
- 到期后必须自动释放 assertion 并关闭相关状态。

合盖运行功能：

- 一等支持场景：拔掉电源 + 合上盖子 + 无外接显示器 + 内置屏幕熄灭时，系统不进入睡眠，已运行的软件继续执行；带外接显示器的同等场景也必须成立。
- 开启前必须读取并保存原始 `disablesleep` 状态。
- 开启时通过 helper 执行等价于 `pmset -a disablesleep 1` 的白名单操作。
- 关闭、退出、崩溃恢复路径或下次启动时，必须尽量恢复到保存的原始状态。
- 不要无条件恢复成 `0`，除非确认用户原始状态就是 `0` 或没有可恢复快照。
- helper 未安装、未授权或连接失败时，UI 必须显示“需授权”或明确的阻塞原因，普通防休眠能力仍应可用。

## Helper 安全边界

- helper 不允许执行任意 shell 命令。
- helper 只允许白名单电源管理操作：读取/启用/恢复 `disablesleep`，以及无参的 `displaysleepnow`（合盖且无外接显示器时主动熄屏省电，不修改任何 pmset 设置）。
- 不要在主 App 中直接运行 `/usr/bin/pmset`、`sudo`、shell 脚本或任意命令来改变系统电源设置。
- 新增 helper 能力时，必须先扩展共享协议，再在 helper 侧做参数校验和白名单限制。
- 错误信息要可诊断，但不要暴露不必要的敏感环境信息。

## 保护策略

合盖运行可能导致发热，因此实现或修改相关逻辑时必须保留这些保护规则：

- 「仅接入电源时允许合盖运行」为可选保护，**默认关闭**；开启后断开电源才自动停用合盖运行。默认情况下断电不影响合盖运行。
- 电池低于 20% 自动停用合盖运行（默认开启）。
- 温度过高时自动停用合盖运行。
- 睡眠保护异常时发通知。
- App 退出时尽量恢复原系统设置。
- 下次启动发现遗留合盖运行状态时，必须尝试恢复。

如果改动影响保护规则，必须同时检查状态机、通知、日志和 UI 展示。

## UI 要求

- 主要界面是 macOS 顶栏 popover，目标尺寸约 `360 x 600`。
- 使用简体中文。
- 第一屏必须突出“合盖运行”。
- 顶部显示 LidRun 标题、总开关、当前状态。
- 内容应包含合盖运行、持续时间、防休眠选项、保护规则、设置、关于、退出。
- 使用原生 macOS 视觉：半透明材质、紧凑间距、SF Pro 系统字体、蓝色强调色。
- 风格参考 Caffeinated，但更专业、更强调合盖运行。
- 不要做大卡片堆叠、花哨插画、营销区块或网页式布局。
- 菜单栏图标必须反映当前激活状态，并支持彩色/单色切换。
- 左键快速切换行为应由设置控制；需要打开界面时使用 popover。

## 系统集成

- 登录启动使用 Launch Services / `SMAppService`。
- 通知使用 `UserNotifications`。
- 电源状态监听使用 IOKit power source API，并监听 AC / battery 切换。
- 关键状态变化必须写入系统日志，方便通过 `log stream` 调试。
- 全局键盘快捷键应保持小而稳定，不要引入重型依赖。

## 编码约定

- 优先沿用现有模块和命名，不要为小改动引入新架构。
- SwiftUI View 保持紧凑，复杂状态逻辑放在 Store / Service 中。
- 与电源状态、helper、恢复逻辑有关的代码必须显式处理失败路径。
- 修改退出、倒计时、helper、`disablesleep` 恢复逻辑时，要特别检查是否会遗留系统设置。
- 文件和注释默认使用中文面向产品语义，API 名称保持清晰英文。
- 不要把 `pmset` 输出解析写成脆弱的散落字符串逻辑；应集中在 helper 控制器里处理。

## 验证命令

常规构建：

```bash
swift build
```

构建并启动菜单栏 App：

```bash
./script/build_and_run.sh --verify
```

查看应用日志：

```bash
./script/build_and_run.sh --logs
```

查看 LidRun subsystem 日志：

```bash
./script/build_and_run.sh --telemetry
```

开发期测试 helper：用 Developer ID 签名包从稳定位置运行（普通 swift build / ad-hoc 包无法注册 SMAppService helper）：

```bash
./script/dev_signed_run.sh
```

清理与签名包冲突的旧版 ad-hoc helper（需管理员权限，仅在用户明确要求时运行）：

```bash
sudo ./script/install_helper_dev.sh --cleanup
```

验证合盖运行相关改动时，至少检查：

- helper 未安装时 UI 是否显示需授权。
- helper 安装后能否读取并保存原始 `disablesleep`。
- 开启合盖运行后能否设置 `disablesleep = 1`。
- 关闭、退出、重新启动恢复路径能否恢复原值。
- 拔电源 + 合盖 + 无外接显示器场景下系统不休眠、进程继续。
- 低电量、温度过高保护是否会自动停用并通知；「仅接入电源」保护仅在用户手动开启后才在断电时停用。

## 禁止事项

- 不要引入跨平台 UI 壳或网页运行时。
- 不要把合盖运行降级成普通 caffeinate 行为。
- 不要绕过 helper 在主 App 中执行管理员命令。
- 不要让 helper 接受任意命令、任意参数或任意 shell 字符串。
- 不要在退出、异常或保护规则触发后遗留错误的系统电源设置。
- 不要把菜单栏工具做成普通窗口应用。
