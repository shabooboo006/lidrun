#!/usr/bin/env bash
set -euo pipefail

# 已废弃：旧的 ad-hoc /Library/LaunchDaemons helper 安装方式与签名包冲突。
# 现在本脚本只做清理：移除旧版 helper，使签名 SMAppService 路径不再被干扰。
# 安装/运行请改用 script/dev_signed_run.sh。

HELPER_LABEL="com.xiachy.LidRun.Helper"
HELPER_TARGET="/Library/PrivilegedHelperTools/$HELPER_LABEL"
PLIST_TARGET="/Library/LaunchDaemons/$HELPER_LABEL.plist"

if [[ "${1:-}" != "--cleanup" ]]; then
  echo "用法: sudo $0 --cleanup"
  echo "（本脚本已不再安装旧版 helper；安装请用 script/dev_signed_run.sh）"
  exit 2
fi

echo "Booting out and removing legacy helper ..."
sudo launchctl bootout "system/$HELPER_LABEL" >/dev/null 2>&1 || true
sudo rm -f "$PLIST_TARGET" "$HELPER_TARGET"

if [[ ! -e "$PLIST_TARGET" && ! -e "$HELPER_TARGET" ]]; then
  echo "Legacy helper removed. 现在用 script/dev_signed_run.sh 安装签名包。"
else
  echo "清理未完全成功，请手动检查 $PLIST_TARGET 和 $HELPER_TARGET" >&2
  exit 1
fi
