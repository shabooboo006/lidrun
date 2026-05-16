#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/install_helper_dev.sh"

echo
echo "LidRun helper 授权安装完成。可以回到菜单栏重新检测或开启合盖运行。"
printf "按任意键关闭此窗口..."
IFS= read -r -n 1 _ || true
echo
