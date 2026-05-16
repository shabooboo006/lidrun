#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="LidRun"
HELPER_NAME="LidRunHelper"
BUNDLE_ID="com.xiachy.LidRun"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_LIBRARY="$APP_CONTENTS/Library"
APP_LAUNCH_DAEMONS="$APP_LIBRARY/LaunchDaemons"
APP_BINARY="$APP_MACOS/$APP_NAME"
HELPER_LABEL="com.xiachy.LidRun.Helper"
HELPER_BINARY="$APP_LAUNCH_DAEMONS/$HELPER_LABEL"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON_SOURCE="$ROOT_DIR/Packaging/macOS/AppIcon.icns"

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build
"$ROOT_DIR/script/build_icon.sh" >/dev/null
BUILD_BIN_DIR="$(swift build --show-bin-path)"
BUILD_BINARY="$BUILD_BIN_DIR/$APP_NAME"
BUILD_HELPER="$BUILD_BIN_DIR/$HELPER_NAME"
BUILD_RESOURCE_BUNDLE="$BUILD_BIN_DIR/${APP_NAME}_${APP_NAME}.bundle"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$APP_LAUNCH_DAEMONS"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$BUILD_HELPER" "$HELPER_BINARY"
cp "$ROOT_DIR/Sources/LidRun/Resources/LaunchDaemons/com.xiachy.LidRun.Helper.plist" "$APP_LAUNCH_DAEMONS/"
if [[ -f "$APP_ICON_SOURCE" ]]; then
  cp "$APP_ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
fi
if [[ -d "$BUILD_RESOURCE_BUNDLE" ]]; then
  cp -R "$BUILD_RESOURCE_BUNDLE" "$APP_BUNDLE/"
fi
chmod +x "$APP_BINARY" "$HELPER_BINARY"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$HELPER_BINARY" >/dev/null 2>&1 || true
  codesign --force --sign - "$APP_BINARY" >/dev/null 2>&1 || true
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSUserNotificationAlertStyle</key>
  <string>alert</string>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
