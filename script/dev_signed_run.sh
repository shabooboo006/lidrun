#!/usr/bin/env bash
set -euo pipefail

# Developer ID 签名的本地运行流程。SMAppService 需要稳定签名包 + 稳定位置，
# 因此安装到 /Applications 后启动（普通 swift build / ad-hoc 无法测 helper）。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="LidRun"
INSTALL_DIR="/Applications"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME.app"

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

SIGNING_MODE=developer-id "$ROOT_DIR/script/build_macos_release.sh"
BUILT_APP="$ROOT_DIR/dist/$APP_NAME.app"

echo "Installing signed app to $INSTALLED_APP"
rm -rf "$INSTALLED_APP"
ditto "$BUILT_APP" "$INSTALLED_APP"

codesign --verify --deep --strict --verbose=2 "$INSTALLED_APP"
echo "Gatekeeper assessment:"
spctl --assess --type execute --verbose=4 "$INSTALLED_APP" || \
  echo "(spctl rejected — expected without notarization; SMAppService still works locally with Developer ID)"

/usr/bin/open "$INSTALLED_APP"
echo "Launched $INSTALLED_APP — register the helper from the menu-bar popover."
