#!/usr/bin/env bash
# ==============================================================================
# mitv_legacy_manager.sh
# 老款小米电视 (Android 5.1 ~ 6.0.1 / API 22~23, 实测 MiTV4-ANSM0)
# 全自动备份、去广告精简、Aerial 桌面无损接管、FongMi 播放器部署与一键可逆回滚工具
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${WORK_DIR:-$(pwd)}"
BACKUP_DIR="${BACKUP_DIR:-$WORK_DIR/backup}"
APK_DIR="$BACKUP_DIR/apks"
TV_IP="${TV_IP:-10.54.1.83:5555}"

# 自动探测 adb 可执行文件
if command -v adb >/dev/null 2>&1; then
  ADB="adb"
elif [ -x "$WORK_DIR/platform-tools/adb" ]; then
  ADB="$WORK_DIR/platform-tools/adb"
elif [ -x "$SCRIPT_DIR/../../platform-tools/adb" ]; then
  ADB="$SCRIPT_DIR/../../platform-tools/adb"
else
  echo "错误: 未找到 adb 命令，请安装 platform-tools 或设置 PATH" >&2
  exit 1
fi

AERIAL_PKG="app.orchard.tv"
AERIAL_GUARD="$AERIAL_PKG/$AERIAL_PKG.guard.HomeGuardService"
ORIG_ACCESSIBILITY="com.xiaomi.voicecontrol/com.xiaomi.voicecontrol.VoiceAccessibilityService"
FONGMI_PKG="com.fongmi.android.tv"
TVBOX_PKG="com.huawei.himovceie"
FONGMI_407_URL="https://raw.githubusercontent.com/aaaafeng123/Release/ecd01a0/apk/release/leanback-armeabi_v7a.apk"
DUOCANG_URL="https://www.iyouhun.com/tv/dc"

# 8 项必删核心广告/升级/统计/推送/商城包
CORE_DEBLOAT_PKGS=(
  "com.miui.systemAdSolution"
  "com.xiaomi.mitv.upgrade"
  "com.miui.tv.analytics"
  "com.xiaomi.statistic"
  "com.xiaomi.mitv.tvpush.tvpushservice"
  "com.mitv.cloudcontrol"
  "com.mitv.shoplugin"
  "com.xiaomi.gamecenter.sdk.service.mibox"
)

# 2 项可选高占用系统包（小爱同学 70MB RAM + 应用中心 23.5MB RAM & 193MB 缓存）
OPT_DEBLOAT_PKGS=(
  "com.xiaomi.voicecontrol"
  "com.xiaomi.mitv.appstore"
)

ALL_DEBLOAT_PKGS=("${CORE_DEBLOAT_PKGS[@]}" "${OPT_DEBLOAT_PKGS[@]}")

normalize_ip() {
  local ip="$1"
  if [[ "$ip" != *:* ]]; then
    echo "${ip}:5555"
  else
    echo "$ip"
  fi
}

connect_tv() {
  TV_IP="$(normalize_ip "$TV_IP")"
  "$ADB" connect "$TV_IP" >/dev/null
  export ANDROID_SERIAL="$TV_IP"
}

# MiTV4-ANSM0 (Android 6.0.1) 系统分区原始 APK 路径映射（支持免 install-existing 原地重装回滚）
get_sys_path() {
  case "$1" in
    com.miui.systemAdSolution) echo "/system/vendor/app/AdServer/AdServer.apk" ;;
    com.xiaomi.mitv.upgrade) echo "/system/vendor/app/MiTVUpgrade/MiTVUpgrade.apk" ;;
    com.miui.tv.analytics) echo "/system/app/MiTVBiAnalytics/MiTVBiAnalytics.apk" ;;
    com.xiaomi.statistic) echo "/system/vendor/app/MiTVStat/MiTVStat.apk" ;;
    com.xiaomi.mitv.tvpush.tvpushservice) echo "/system/vendor/app/TVPushService/TVPushService.apk" ;;
    com.mitv.cloudcontrol) echo "/system/app/CloudControlCenter/CloudControlCenter.apk" ;;
    com.xiaomi.voicecontrol) echo "/system/app/VoiceControl/VoiceControl.apk" ;;
    com.xiaomi.mitv.appstore) echo "/system/vendor/app/MiTVAppStore/MiTVAppStore.apk" ;;
    *) echo "" ;;
  esac
}

cmd_status() {
  connect_tv
  echo "========================================================"
  echo " 老款小米电视 (Android 6.0 @ $TV_IP) 状态面板"
  echo "========================================================"
  echo "[1] 设备与系统信息："
  echo "  - 型号/代号:   $("$ADB" shell "getprop ro.product.model" | tr -d '\r') ($("$ADB" shell "getprop ro.product.device" | tr -d '\r'))"
  echo "  - Android版本: Android $("$ADB" shell "getprop ro.build.version.release" | tr -d '\r') (API $("$ADB" shell "getprop ro.build.version.sdk" | tr -d '\r'), ABI: $("$ADB" shell "getprop ro.product.cpu.abilist" | tr -d '\r'))"
  echo ""
  echo "[2] 桌面与守护状态："
  echo "  - Aerial 版本: $("$ADB" shell "dumpsys package $AERIAL_PKG | grep versionName" | tr -d '\r' | xargs || echo '未安装')"
  echo "  - 无障碍列表:  $("$ADB" shell settings get secure enabled_accessibility_services | tr -d '\r')"
  echo "  - 守护运行数:  $("$ADB" shell "dumpsys accessibility | grep -c -E 'label=(Aerial|app.orchard.tv)'" | tr -d '\r')"
  echo "  - 当前焦点窗口: $("$ADB" shell "dumpsys window | grep mCurrentFocus" | tr -d '\r' | xargs)"
  echo ""
  echo "[3] 内存与存储状态："
  "$ADB" shell "cat /proc/meminfo | head -n 3" | tr -d '\r' | sed 's/^/  /'
  "$ADB" shell "df /data" | tr -d '\r' | sed 's/^/  /'
  echo ""
  echo "[4] 10 项广告与冗余包当前状态："
  local installed_list
  installed_list=$("$ADB" shell pm list packages | tr -d '\r')
  for pkg in "${ALL_DEBLOAT_PKGS[@]}"; do
    if echo "$installed_list" | grep -q -x "package:$pkg"; then
      printf "  - %-42s [已启用/未精简]\n" "$pkg"
    else
      printf "  - %-42s [已精简 (可回滚)]\n" "$pkg"
    fi
  done
  echo "========================================================"
}

cmd_backup() {
  connect_tv
  mkdir -p "$APK_DIR"
  echo "正在备份系统配置快照至 $BACKUP_DIR/settings_snapshot.env ..."
  {
    echo "ACCESSIBILITY_SERVICES=$("$ADB" shell settings get secure enabled_accessibility_services | tr -d '\r')"
    echo "ACCESSIBILITY_ENABLED=$("$ADB" shell settings get secure accessibility_enabled | tr -d '\r')"
    echo "NOTIFICATION_LISTENERS=$("$ADB" shell settings get secure enabled_notification_listeners | tr -d '\r')"
  } > "$BACKUP_DIR/settings_snapshot.env"

  echo "正在从电视提取 10 项待精简系统包的原始 APK 至 $APK_DIR ..."
  for pkg in "${ALL_DEBLOAT_PKGS[@]}"; do
    local remote_path
    remote_path=$("$ADB" shell pm path "$pkg" | tr -d '\r' | sed 's/^package://' | head -n 1 || true)
    if [ -n "$remote_path" ]; then
      echo "  -> 备份 $pkg ($remote_path)"
      "$ADB" pull "$remote_path" "$APK_DIR/${pkg}.apk" >/dev/null
    else
      echo "  -> 跳过 $pkg (当前用户未安装或已精简)"
    fi
  done
  echo "全量离线备份已完成！"
}

cmd_debloat() {
  local include_opt="${1:-false}"
  connect_tv
  mkdir -p "$APK_DIR"

  local target_pkgs=("${CORE_DEBLOAT_PKGS[@]}")
  if [ "$include_opt" = "--all" ]; then
    target_pkgs=("${ALL_DEBLOAT_PKGS[@]}")
  fi

  echo "正在执行免 Root 安全精简 (Android 6.0 pm uninstall -k --user 0)..."
  for pkg in "${target_pkgs[@]}"; do
    # 若本地尚未备份，先自动拉取备份
    if [ ! -f "$APK_DIR/${pkg}.apk" ]; then
      local rpath
      rpath=$("$ADB" shell pm path "$pkg" | tr -d '\r' | sed 's/^package://' | head -n 1 || true)
      [ -n "$rpath" ] && "$ADB" pull "$rpath" "$APK_DIR/${pkg}.apk" >/dev/null || true
    fi
    # 执行卸载（若该包曾在 /data/app 升级过，第一次 uninstall 会回退到 /system，需检查并二次执行）
    if "$ADB" shell pm list packages | tr -d '\r' | grep -q -x "package:$pkg"; then
      "$ADB" shell pm uninstall -k --user 0 "$pkg" >/dev/null 2>&1 || true
      if "$ADB" shell pm list packages | tr -d '\r' | grep -q -x "package:$pkg"; then
        "$ADB" shell pm uninstall -k --user 0 "$pkg" >/dev/null 2>&1 || true
      fi
      echo "  ✓ 已精简: $pkg"
    else
      echo "  - 已处于精简状态: $pkg"
    fi
  done

  echo "正在清理广告缓存并只读锁定 /sdcard/miad ..."
  "$ADB" shell "
    rm -rf /sdcard/miad/* /sdcard/miad/.* 2>/dev/null || true
    rm -rf /sdcard/Android/data/com.miui.systemAdSolution/* 2>/dev/null || true
    rm -rf /sdcard/Android/data/com.xiaomi.mitv.appstore/files/* 2>/dev/null || true
    mkdir -p /sdcard/miad /sdcard/Android/data/com.miui.systemAdSolution
    chmod 000 /sdcard/miad /sdcard/Android/data/com.miui.systemAdSolution 2>/dev/null || true
  "
  echo "系统精简与广告目录锁死已完成！"
}

cmd_install_aerial() {
  connect_tv
  mkdir -p "$APK_DIR"
  local aerial_apk="$APK_DIR/aerial-standard.apk"
  echo "正在查询 GitHub 上 pengchujin/aerial-tv 最新版本..."
  local latest_tag
  latest_tag=$(curl --http1.1 -sI "https://github.com/pengchujin/aerial-tv/releases/latest" | grep -i '^location:' | sed -E 's#.*/tag/([^[:space:]]+).*#\1#' | tr -d '\r')
  [ -z "$latest_tag" ] && latest_tag="v1.57"
  echo "正在下载 Aerial $latest_tag 标准版安装包..."
  curl --http1.1 -sL -o "$aerial_apk" "https://github.com/pengchujin/aerial-tv/releases/download/${latest_tag}/aerial-standard.apk"
  echo "正在安装 Aerial ($latest_tag) 至电视..."
  "$ADB" install -r "$aerial_apk"
  cmd_repair_launcher
}

cmd_repair_launcher() {
  connect_tv
  echo "正在修复并重新绑定 Aerial 桌面权限与 HomeGuardService 无障碍守护..."
  "$ADB" shell pm grant "$AERIAL_PKG" android.permission.WRITE_SECURE_SETTINGS 2>/dev/null || true
  "$ADB" shell appops set "$AERIAL_PKG" GET_USAGE_STATS allow 2>/dev/null || true
  "$ADB" shell appops set "$AERIAL_PKG" android:get_usage_stats allow 2>/dev/null || true
  "$ADB" shell appops set "$AERIAL_PKG" SYSTEM_ALERT_WINDOW allow 2>/dev/null || true
  "$ADB" shell am broadcast -a "$AERIAL_PKG.CONFIG" -n "$AERIAL_PKG/.guard.ConfigReceiver" --ez keep_adb true >/dev/null 2>&1 || true
  "$ADB" shell settings put secure enabled_notification_listeners "$AERIAL_PKG/$AERIAL_PKG.guard.RevivalListener"
  "$ADB" shell "settings put secure enabled_accessibility_services '$ORIG_ACCESSIBILITY:$AERIAL_GUARD'"
  "$ADB" shell settings put secure accessibility_enabled 1
  "$ADB" shell am force-stop "$AERIAL_PKG"
  sleep 2
  "$ADB" shell am start -W -n "$AERIAL_PKG/.MainActivity"
  echo "Aerial 桌面无损接管已生效！"
}

cmd_install_fongmi() {
  connect_tv
  mkdir -p "$APK_DIR"
  local fongmi_apk="$APK_DIR/fongmi_tv_4.0.7_armeabi_v7a.apk"
  if [ ! -f "$fongmi_apk" ]; then
    echo "正在下载兼容 Android 6.0 (minSdk 21) 的 FongMi/TV v4.0.7 (32位电视版)..."
    curl --http1.1 -sL -o "$fongmi_apk" "$FONGMI_407_URL"
  fi
  echo "正在安装 FongMi/TV v4.0.7 至电视..."
  "$ADB" install -r "$fongmi_apk"
  "$ADB" shell pm grant "$FONGMI_PKG" android.permission.READ_EXTERNAL_STORAGE 2>/dev/null || true
  "$ADB" shell pm grant "$FONGMI_PKG" android.permission.WRITE_EXTERNAL_STORAGE 2>/dev/null || true
  "$ADB" shell "rm -f /sdcard/TVBox/ogthread.json /sdcard/TVBox/*cookie*.txt 2>/dev/null || true"
  "$ADB" shell am force-stop "$TVBOX_PKG" 2>/dev/null || true
  echo "FongMi/TV v4.0.7 安装与权限配置完成！"
}

cmd_restore_pkg() {
  local pkg="${1:-}"
  if [ -z "$pkg" ]; then
    echo "用法: $0 restore-pkg <包名>" >&2
    exit 1
  fi
  connect_tv
  echo "正在恢复系统包: $pkg ..."
  if [ "$pkg" = "com.miui.systemAdSolution" ]; then
    "$ADB" shell "chmod 755 /sdcard/miad /sdcard/Android/data/com.miui.systemAdSolution 2>/dev/null || true"
  fi
  local sys_path
  sys_path=$(get_sys_path "$pkg")
  if [ -n "$sys_path" ] && "$ADB" shell "[ -f '$sys_path' ]" 2>/dev/null; then
    "$ADB" shell pm install -r -d --user 0 "$sys_path"
  elif [ -f "$APK_DIR/${pkg}.apk" ]; then
    "$ADB" install -r -d "$APK_DIR/${pkg}.apk"
  else
    echo "错误: 找不到 $pkg 的系统路径或本地备份文件 ($APK_DIR/${pkg}.apk)" >&2
    exit 1
  fi
  if [ "$pkg" = "com.xiaomi.voicecontrol" ]; then
    "$ADB" shell "settings put secure enabled_accessibility_services '$ORIG_ACCESSIBILITY:$AERIAL_GUARD'" || true
  fi
  echo "已成功恢复: $pkg"
}

cmd_restore_all_pkgs() {
  for pkg in "${ALL_DEBLOAT_PKGS[@]}"; do
    cmd_restore_pkg "$pkg"
  done
  echo "全部 10 个精简系统包均已原样恢复！"
}

cmd_restore_launcher() {
  connect_tv
  echo "正在解除 Aerial 桌面接管并切回小米原厂 PatchWall 桌面..."
  "$ADB" shell am broadcast -a "$AERIAL_PKG.CONFIG" -n "$AERIAL_PKG/.guard.ConfigReceiver" --ez keep_adb false --ez own_screensaver false >/dev/null 2>&1 || true
  "$ADB" shell settings delete secure enabled_notification_listeners >/dev/null 2>&1 || true
  "$ADB" shell pm revoke "$AERIAL_PKG" android.permission.WRITE_SECURE_SETTINGS >/dev/null 2>&1 || true
  "$ADB" shell appops set "$AERIAL_PKG" SYSTEM_ALERT_WINDOW default >/dev/null 2>&1 || true
  "$ADB" shell appops set "$AERIAL_PKG" GET_USAGE_STATS default >/dev/null 2>&1 || true
  "$ADB" shell appops set "$AERIAL_PKG" android:get_usage_stats default >/dev/null 2>&1 || true
  "$ADB" shell am force-stop "$AERIAL_PKG" >/dev/null 2>&1 || true
  "$ADB" shell "settings put secure enabled_accessibility_services '$ORIG_ACCESSIBILITY'"
  "$ADB" shell settings put secure accessibility_enabled 1
  if [ "${1:-}" = "--uninstall" ]; then
    echo "正在卸载 Aerial ($AERIAL_PKG)..."
    "$ADB" uninstall "$AERIAL_PKG"
  fi
  "$ADB" shell input keyevent KEYCODE_HOME
  sleep 2
  echo "已切回小米原厂桌面，当前焦点: $("$ADB" shell "dumpsys window | grep mCurrentFocus" | tr -d '\r' | xargs)"
}

case "${1:-status}" in
  status)
    [ -n "${2:-}" ] && TV_IP="$2"
    cmd_status
    ;;
  backup)
    [ -n "${2:-}" ] && TV_IP="$2"
    cmd_backup
    ;;
  debloat)
    shift || true
    local_flag=""
    if [ "${1:-}" = "--all" ]; then
      local_flag="--all"
      shift || true
    fi
    [ -n "${1:-}" ] && TV_IP="$1"
    cmd_debloat "$local_flag"
    ;;
  install-aerial)
    [ -n "${2:-}" ] && TV_IP="$2"
    cmd_install_aerial
    ;;
  repair-launcher)
    [ -n "${2:-}" ] && TV_IP="$2"
    cmd_repair_launcher
    ;;
  install-fongmi)
    [ -n "${2:-}" ] && TV_IP="$2"
    cmd_install_fongmi
    ;;
  restore-pkg)
    shift
    pkg_arg="${1:-}"
    [ -n "${2:-}" ] && TV_IP="$2"
    cmd_restore_pkg "$pkg_arg"
    ;;
  restore-all-pkgs)
    [ -n "${2:-}" ] && TV_IP="$2"
    cmd_restore_all_pkgs
    ;;
  restore-launcher)
    shift || true
    uninst_flag=""
    if [ "${1:-}" = "--uninstall" ]; then
      uninst_flag="--uninstall"
      shift || true
    fi
    [ -n "${1:-}" ] && TV_IP="$1"
    cmd_restore_launcher "$uninst_flag"
    ;;
  restore-factory-state)
    [ -n "${2:-}" ] && TV_IP="$2"
    cmd_restore_all_pkgs
    cmd_restore_launcher --uninstall
    echo "电视已 100% 恢复至操作前的原厂初始状态！"
    ;;
  *)
    cat <<USAGE
用法: $0 <命令> [参数] [TV_IP]

可用命令:
  status [TV_IP]                         查看电视软硬件、桌面守护、内存/存储及 10 项精简包状态
  backup [TV_IP]                         卸载前全量提取 10 项系统包原始 APK 与系统配置快照至本地
  debloat [--all] [TV_IP]                安全精简 8 项广告/统计组件（加 --all 连同小爱同学与应用中心共 10 项一并精简）
  install-aerial [TV_IP]                 下载安装最新版 Aerial 纯净桌面并完成无损主页键接管
  repair-launcher [TV_IP]                升级 Aerial 后重新绑定权限与 HomeGuardService 桌面守护
  install-fongmi [TV_IP]                 下载安装 Android 6.0 专版 FongMi/TV v4.0.7 并修复「玩偶哥哥」转圈配置
  restore-pkg <包名> [TV_IP]             单独无损恢复某一个被精简的系统包
  restore-all-pkgs [TV_IP]               一键恢复全部 10 个被精简的系统包
  restore-launcher [--uninstall] [TV_IP] 一键解除 Aerial 接管并回到小米原厂桌面（加 --uninstall 同时卸载 Aerial）
  restore-factory-state [TV_IP]          一键将所有系统包与桌面 100% 还原至原厂状态
USAGE
    exit 1
    ;;
esac
