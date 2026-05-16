# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Authoritative rules

`AGENTS.md` (Chinese) is the source of truth for product scope, power-management
behavior, safety boundaries, protection policy, and UI requirements. Read it
before changing power, helper, recovery, or protection logic. This file covers
commands and the cross-file architecture; it does not restate `AGENTS.md`.

## Commands

```bash
swift build                          # build both targets (LidRun, LidRunHelper)
./script/build_and_run.sh            # build, assemble dist/LidRun.app, launch via Launch Services
./script/build_and_run.sh --verify   # same, then assert the app process is running
./script/build_and_run.sh --logs     # launch + stream process logs
./script/build_and_run.sh --telemetry# launch + stream subsystem (com.xiachy.LidRun) logs
./script/build_and_run.sh --debug    # run the app binary under lldb
./script/install_helper_dev.sh       # dev-only: sudo-install + bootstrap the privileged helper
```

There are no unit tests and no separate linter; `swift build` is the only
compile/check gate. `build_and_run.sh` regenerates `dist/LidRun.app` and its
`Info.plist` from scratch each run (it does not edit them in place — change the
heredoc in the script, not the generated bundle). Only run
`install_helper_dev.sh` when the user explicitly asks to install/authorize the
helper; it prompts for an admin password.

## Architecture

Two SwiftPM executables plus a shared library, talking over XPC:

- **`LidRun`** — the menu-bar app (SwiftUI + AppKit). `LSUIElement` accessory
  app, no main window.
- **`LidRunHelper`** — a root LaunchDaemon. The *only* component allowed to
  touch system power settings, and only via a hard-coded `pmset disablesleep`
  whitelist.
- **`LidRunShared`** — the `@objc` XPC protocol (`LidRunHelperProtocol`),
  constants, and shared types. Any new helper capability must be added here
  first, then validated/whitelisted on the helper side.

### App composition and lifecycle

`LidRunApp` is `@main` but its only Scene is `Settings`; the real entry point is
`AppDelegate` (`@NSApplicationDelegateAdaptor`). `AppServices.shared` is the
single owner of `AppSettings`, `HelperAuthorizationService`, and `AppState`
(constructed once, injected as `environmentObject`). `AppDelegate` builds the
`StatusItemController` (NSStatusItem + NSPopover) and calls `state.start()`;
`applicationShouldTerminate` returns `.terminateLater` and awaits
`state.shutdown()` so cleanup/restore can complete before exit.

### AppState is the state machine

`Sources/LidRun/Stores/AppState.swift` is the heart of the app. It coordinates
five services (`SleepAssertionController` for IOKit assertions,
`PowerSourceMonitor`, `NotificationService`, `LoginItemService`,
`GlobalHotKeyController`) and the helper, and owns the countdown timer and the
`lidRunState` lifecycle (`off → enabling → running → restoring → off`, plus
`blocked(reason)`).

Two concerns are easy to break and must be preserved when editing this file:

1. **disablesleep restore.** Before enabling lid-run, the *original*
   `disablesleep` value is read once and persisted in
   `settings.savedDisableSleepValue`. Disable/quit/crash-recovery paths restore
   *that saved value*, never an unconditional `0`. `restoreStaleLidRunStateIfNeeded()`
   runs at startup so a leftover state from a crash/forced quit is recovered.
2. **Protection rules.** `protectionDecision(for:)` centralizes the
   AC-only / low-battery / thermal gates. `enforceProtectionRules` is invoked on
   every `PowerSourceMonitor` change and auto-disables lid-run (with
   notification + log) when a gate trips. Normal anti-idle-sleep (IOKit
   assertions) keeps working even when the helper is unavailable.

### Helper / XPC path

`AppState` never calls `pmset`. It goes:
`HelperAuthorizationService` → `HelperXPCClient` → XPC → `HelperService` →
`PMSetController`.

- `HelperAuthorizationService` registers the daemon via
  `SMAppService.daemon(plistName:)` and tracks `HelperStatus`; `refreshStatus()`
  pings the helper to distinguish *installed* from *needs authorization*.
- `HelperXPCClient` wraps the completion-handler protocol in async/await, lazily
  builds a `.privileged` `NSXPCConnection`, and treats proxy/connection errors
  as a normal "helper unavailable" path (UI shows 需授权, anti-idle still works).
- `PMSetController` is the single place that shells out to `/usr/bin/pmset`;
  output parsing for `disablesleep` lives only here. Do not scatter `pmset`
  string parsing or run privileged commands anywhere else.

The helper's mach service name, label, and bundle id are in
`LidRunConstants`; the LaunchDaemon plist is
`Sources/LidRun/Resources/LaunchDaemons/com.xiachy.LidRun.Helper.plist` (copied
into the app bundle by `build_and_run.sh` and installed to
`/Library/LaunchDaemons/` by `install_helper_dev.sh`).

## Conventions

- Product-facing comments and user-visible strings are Simplified Chinese; API
  / type names stay in clear English. Follow the existing module layout rather
  than introducing new architecture for small changes.
- SwiftUI views stay thin; state/power/helper logic lives in
  `Stores`/`Services`. Code touching power state, the helper, or recovery must
  handle failure paths explicitly.
- When changing quit, countdown, helper, or `disablesleep` restore logic,
  re-check that no path can leave a wrong system power setting behind, and keep
  the state machine, notifications, logs, and UI in sync.
