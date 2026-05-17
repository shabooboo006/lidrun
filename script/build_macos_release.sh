#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUILD_DIR="$DIST_DIR/build"
APP_DIR="$DIST_DIR/LidRun.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
LIBRARY_DIR="$CONTENTS_DIR/Library"
LAUNCH_DAEMONS_DIR="$LIBRARY_DIR/LaunchDaemons"
PLIST_TEMPLATE="$ROOT_DIR/Packaging/macOS/Info.plist"
PLIST_PATH="$CONTENTS_DIR/Info.plist"
ICON_BUILD_SCRIPT="$ROOT_DIR/script/build_icon.sh"
ICON_SOURCE_DIR="$ROOT_DIR/Packaging/macOS/AppIcon.appiconset"
ICON_ICNS_PATH="$ROOT_DIR/Packaging/macOS/AppIcon.icns"

APP_NAME="LidRun"
HELPER_PRODUCT="LidRunHelper"
HELPER_LABEL="com.xiachy.LidRun.Helper"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SIGNING_MODE="${SIGNING_MODE:-adhoc}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-}"
KEYCHAIN_PATH="${KEYCHAIN_PATH:-}"

info() {
  printf '%s\n' "$*" >&2
}

detect_app_sign_identity() {
  local output
  if [[ -n "$KEYCHAIN_PATH" ]]; then
    output="$(security find-identity -p codesigning -v "$KEYCHAIN_PATH" 2>/dev/null || true)"
  else
    output="$(security find-identity -p codesigning -v 2>/dev/null || true)"
  fi
  printf '%s\n' "$output" | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -n 1
}

configure_signing() {
  case "$SIGNING_MODE" in
    adhoc)
      CODESIGN_ARGS=(--force --sign -)
      ;;
    developer-id)
      if [[ -z "$APP_SIGN_IDENTITY" ]]; then
        APP_SIGN_IDENTITY="$(detect_app_sign_identity)"
      fi
      if [[ -z "$APP_SIGN_IDENTITY" ]]; then
        info "ERROR: SIGNING_MODE=developer-id but no Developer ID Application certificate was found."
        info "Set APP_SIGN_IDENTITY explicitly or install a Developer ID Application certificate."
        exit 1
      fi
      CODESIGN_ARGS=(--force --timestamp --options runtime --sign "$APP_SIGN_IDENTITY")
      ;;
    *)
      info "ERROR: Unsupported SIGNING_MODE '$SIGNING_MODE'. Expected 'adhoc' or 'developer-id'."
      exit 1
      ;;
  esac
}

sign_release_bundle() {
  configure_signing
  chmod -R u+w "$APP_DIR"
  find "$APP_DIR" -exec xattr -c {} + 2>/dev/null || true
  find "$APP_DIR" -name '._*' -delete

  codesign "${CODESIGN_ARGS[@]}" --identifier "$HELPER_LABEL" "$LAUNCH_DAEMONS_DIR/$HELPER_LABEL"
  codesign "${CODESIGN_ARGS[@]}" "$MACOS_DIR/$APP_NAME"
  codesign "${CODESIGN_ARGS[@]}" "$APP_DIR"
}

cd "$ROOT_DIR"
rm -rf "$BUILD_DIR" "$APP_DIR"
mkdir -p "$BUILD_DIR" "$MACOS_DIR" "$RESOURCES_DIR" "$LAUNCH_DAEMONS_DIR"
# 让 Spotlight/LaunchServices 永不索引 dist/，避免构建产物在启动台出现重复图标。
touch "$DIST_DIR/.metadata_never_index"

swift build -c release
"$ICON_BUILD_SCRIPT" "$ICON_SOURCE_DIR" "$ICON_ICNS_PATH" >/dev/null

BIN_DIR="$(swift build -c release --show-bin-path)"
APP_BINARY="$BIN_DIR/$APP_NAME"
HELPER_BINARY="$BIN_DIR/$HELPER_PRODUCT"

cp "$APP_BINARY" "$MACOS_DIR/$APP_NAME"
cp "$HELPER_BINARY" "$LAUNCH_DAEMONS_DIR/$HELPER_LABEL"
cp "$ROOT_DIR/Sources/LidRun/Resources/LaunchDaemons/$HELPER_LABEL.plist" "$LAUNCH_DAEMONS_DIR/$HELPER_LABEL.plist"
cp "$ICON_ICNS_PATH" "$RESOURCES_DIR/AppIcon.icns"
chmod +x "$MACOS_DIR/$APP_NAME" "$LAUNCH_DAEMONS_DIR/$HELPER_LABEL"

sed \
  -e "s/__VERSION__/$VERSION/g" \
  -e "s/__BUILD__/$BUILD_NUMBER/g" \
  "$PLIST_TEMPLATE" > "$PLIST_PATH"

touch "$CONTENTS_DIR/PkgInfo"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

sign_release_bundle
codesign --verify --deep --strict --verbose=2 "$APP_DIR" >/dev/null
echo "$APP_DIR"
