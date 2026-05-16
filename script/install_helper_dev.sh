#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER_LABEL="com.xiachy.LidRun.Helper"
HELPER_TARGET="/Library/PrivilegedHelperTools/$HELPER_LABEL"
PLIST_TARGET="/Library/LaunchDaemons/$HELPER_LABEL.plist"
TMP_PLIST="$(mktemp -t LidRunHelper.XXXXXX.plist)"

cleanup() {
  rm -f "$TMP_PLIST"
}
trap cleanup EXIT

cd "$ROOT_DIR"
swift build --product LidRunHelper
HELPER_BUILD="$(swift build --show-bin-path)/LidRunHelper"

cat >"$TMP_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$HELPER_LABEL</string>
  <key>MachServices</key>
  <dict>
    <key>$HELPER_LABEL</key>
    <true/>
  </dict>
  <key>ProgramArguments</key>
  <array>
    <string>$HELPER_TARGET</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardErrorPath</key>
  <string>/var/log/LidRunHelper.error.log</string>
  <key>StandardOutPath</key>
  <string>/var/log/LidRunHelper.log</string>
</dict>
</plist>
PLIST

sudo install -o root -g wheel -m 544 "$HELPER_BUILD" "$HELPER_TARGET"
sudo install -o root -g wheel -m 644 "$TMP_PLIST" "$PLIST_TARGET"

sudo launchctl bootout system "$PLIST_TARGET" >/dev/null 2>&1 || true
sudo launchctl bootstrap system "$PLIST_TARGET"
sudo launchctl kickstart -k "system/$HELPER_LABEL"

if launchctl print "system/$HELPER_LABEL" >/dev/null 2>&1; then
  echo "Installed and started $HELPER_LABEL"
else
  echo "Installed $HELPER_LABEL, but launchctl did not report it as running" >&2
  exit 1
fi
