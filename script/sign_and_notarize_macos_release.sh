#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export SIGNING_MODE="${SIGNING_MODE:-developer-id}"
export NOTARIZE="${NOTARIZE:-1}"
export NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-CodeRelayNotary}"
export PACKAGE_FORMATS="${PACKAGE_FORMATS:-zip dmg}"

exec "$ROOT_DIR/script/package_macos_release.sh"
