#!/usr/bin/env bash
# LidRun helper 诊断：收集 SMAppService / BTM / launchd / 代码签名 状态。
# 用法： sudo ./script/diagnose_helper.sh 2>&1 | tee /tmp/lidrun_diag.txt
# 然后把 /tmp/lidrun_diag.txt 的内容贴回给我。不修改任何系统状态，只读。
set +e

LABEL="com.xiachy.LidRun.Helper"
APP="/Applications/LidRun.app"
line(){ printf '\n===== %s =====\n' "$1"; }

line "macOS / context"
sw_vers
echo "whoami=$(whoami)  (期望以 sudo 运行)"

line "running LidRun process + path"
ps axo pid,command | grep "[L]idRun.app/Contents/MacOS/LidRun" || echo "(LidRun 未运行)"

line "installed bundle: signature / notarization / structure"
ls -ld "$APP" 2>&1
codesign -dv --verbose=4 "$APP" 2>&1 | grep -iE "Identifier=|TeamIdentifier|Authority=|flags=|Sealed" | head -8
echo "spctl: $(spctl -a -vvv -t exec "$APP" 2>&1 | tail -1)"
echo "stapler: $(xcrun stapler validate "$APP" 2>&1 | tail -1)"
echo "quarantine: $(xattr -p com.apple.quarantine "$APP" 2>/dev/null || echo none)"
echo "--- embedded daemon ---"
ls -l "$APP/Contents/Library/LaunchDaemons/" 2>&1
echo "--- embedded plist ---"
plutil -p "$APP/Contents/Library/LaunchDaemons/$LABEL.plist" 2>&1
echo "--- embedded helper codesign ---"
codesign -dv --verbose=4 "$APP/Contents/Library/LaunchDaemons/$LABEL" 2>&1 | grep -iE "Identifier=|TeamIdentifier|Authority=|flags=" | head -6

line "Background Task Management DB (sfltool dumpbtm — needs sudo+FDA)"
sfltool dumpbtm 2>&1 | grep -iB2 -A14 "lidrun" || echo "(无 lidrun 记录 / sfltool 需要 sudo + 终端的完全磁盘访问权限)"

line "launchd system-domain daemon"
launchctl print "system/$LABEL" 2>&1 | sed -n '1,30p' || echo "(系统域未加载该 daemon)"
launchctl print-disabled system 2>&1 | grep -i lidrun || echo "(disabled 列表无 lidrun)"

line "legacy ad-hoc remnants (should be gone)"
ls -l "/Library/LaunchDaemons/$LABEL.plist" "/Library/PrivilegedHelperTools/$LABEL" 2>&1

line "Service Management / smd / LidRun logs (last 15 min)"
log show --last 15m --info --debug \
  --predicate '(process == "smd") OR (process == "LidRun") OR (process == "backgroundtaskmanagementd") OR (subsystem == "com.apple.servicemanagement") OR (subsystem == "com.xiachy.LidRun")' \
  2>/dev/null | grep -iE "lidrun|daemon|notFound|not found|registr|approv|signature|gatekeeper|denied|invalid|bundleprogram|XPC|Sandbox|disallow" | tail -50 \
  || echo "(无匹配日志)"

line "DONE"
echo "把以上完整输出贴回给我（或发送 /tmp/lidrun_diag.txt 的内容）。"
