# 开源桌面选型与 Aerial 无损接管技术指南（Android 6.0 专版）

## 一、为什么在 Android 6.0 上选择 `pengchujin/aerial-tv`？

针对老款小米电视（Android 6.0.1，API 23），对比主流开源 TV 桌面仓库：

| 评估维度 | `lesnolie/Tigris` | `Projectivy Launcher` (`tv-fresh` 方案) | `pengchujin/aerial-tv` (**Aerial，本技能选用**) |
| :--- | :--- | :--- | :--- |
| **最低系统要求 (`minSdk`)** | `minSdk 28`（仅支持 Android 9.0+） | 支持旧版，但在 MIUI TV 上依赖卸载 `tvhome` + 禁用 `FallbackHome` | **`minSdk 21`（原生支持 Android 5.0 ~ 6.0.1+）** |
| **Android 6.0 兼容性** | ❌ **完全无法安装**（报错 `INSTALL_FAILED_OLDER_SDK`） | ⚠️ 在 Android 6.0 上卸载 `tvhome` 易触发主页键失效或黑屏 | ✅ **专为小米 Android 6.0 做了 `GET_USAGE_STATS` 与无障碍接管适配** |
| **接管原理与安全性** | 需替换系统 HOME | 需卸载 `com.mitv.tvhome` 并禁用 `com.android.tv.settings` | **保留原厂桌面不卸载**，通过 `HomeGuardService` 无障碍服务拦截并接管 HOME 键与开机桌面，100% 零变砖风险 |
| **资源占用与包体积** | - | ~8 MB，功能较重 | **仅 2.8 MB**（`aerial-standard.apk`），极简极速，内存占用极低 |

---

## 二、Aerial 安装与无损接管完整流程

### 1. 获取最新安装包
从 GitHub Releases 下载标准版 `aerial-standard.apk`（支持在线壁纸与完整桌面守护）：
```bash
# 查询最新 Release 标签（截至 2026-10 最新版为 v1.57，versionCode=69）
curl --http1.1 -sI "https://github.com/pengchujin/aerial-tv/releases/latest" | grep -i location

# 下载最新 aerial-standard.apk
curl --http1.1 -sL -o aerial.apk "https://github.com/pengchujin/aerial-tv/releases/download/v1.57/aerial-standard.apk"
```

### 2. 安装 APK 并授予核心权限
在小米电视 Android 6.0.1 上，`Aerial` (`app.orchard.tv`) 需要以下三项核心权限才能实现自动守护、前台应用检测（Android 6.0 专需 `GET_USAGE_STATS`）与 ADB 自保持：

```bash
# 1. 安装或覆盖升级 Aerial
adb install -r aerial.apk

# 2. 授予修改安全设置权限（允许 Aerial 自身维护无障碍与 ADB 状态）
adb shell pm grant app.orchard.tv android.permission.WRITE_SECURE_SETTINGS 2>/dev/null

# 3. 授予 Android 6.0 必需的 AppOps 权限（使用情况访问 + 悬浮窗）
adb shell appops set app.orchard.tv GET_USAGE_STATS allow 2>/dev/null
adb shell appops set app.orchard.tv SYSTEM_ALERT_WINDOW allow 2>/dev/null
adb shell appops set app.orchard.tv WRITE_SETTINGS allow 2>/dev/null
```

### 3. 绑定 `HomeGuardService` 无障碍桌面守护、`RevivalListener` 并开启 `keep_adb`
```bash
# 1. 通过广播配置 Aerial 开启 keep_adb（防止重启后 ADB 调试被复位）
adb shell am broadcast -a app.orchard.tv.CONFIG -n app.orchard.tv/.guard.ConfigReceiver --ez keep_adb true >/dev/null 2>&1 || true

# 2. 绑定通知监听复活服务 RevivalListener 与无障碍守护 HomeGuardService
adb shell settings put secure enabled_notification_listeners "app.orchard.tv/app.orchard.tv.guard.RevivalListener"
adb shell settings put secure enabled_accessibility_services \
  "com.xiaomi.voicecontrol/.VoiceAccessibilityService:app.orchard.tv/app.orchard.tv.guard.HomeGuardService"
adb shell settings put secure accessibility_enabled 1

# 3. 拉起 Aerial 主界面完成初始化
adb shell am start -W -n app.orchard.tv/.MainActivity
```

---

## 三、⚠️ 关键维护点：升级 Aerial 后的无障碍服务自动重绑

**现象与原因**：
当 `Aerial` 发布新版本（例如从 `v1.49` -> `v1.50` -> `v1.57`），使用 `adb install -r aerial.apk` 覆盖安装时，Android 6.0 的 `PackageManagerService` 会在替换包期间短暂解绑该包名下的 `AccessibilityService`，导致覆盖升级后 `enabled_accessibility_services` 中丢失 `app.orchard.tv.guard.HomeGuardService`，按遥控器 HOME 键又跳回原厂桌面。

**标准升级SOP**：
每次执行 `adb install -r aerial.apk` 覆盖升级后，**必须立即跟进执行一次守护修复命令**（已集成在 `scripts/mitv_legacy_manager.sh repair-launcher` 中）：
```bash
adb shell pm grant app.orchard.tv android.permission.WRITE_SECURE_SETTINGS 2>/dev/null
adb shell appops set app.orchard.tv GET_USAGE_STATS allow 2>/dev/null
adb shell appops set app.orchard.tv SYSTEM_ALERT_WINDOW allow 2>/dev/null
adb shell settings put secure enabled_accessibility_services "app.orchard.tv/app.orchard.tv.guard.HomeGuardService"
adb shell settings put secure accessibility_enabled 1
adb shell am start -n app.orchard.tv/.MainActivity
```

---

## 四、验证接管状态与一键回滚原厂桌面

### 1. 验证接管是否生效
```bash
# 发送 HOME 键事件（keyevent 3），等待 1 秒后检查焦点窗口是否落在 app.orchard.tv
adb shell "input keyevent 3 && sleep 1 && dumpsys window windows | grep -E 'mCurrentFocus|mFocusedApp'"
# 预期输出：mCurrentFocus=Window{... u0 app.orchard.tv/app.orchard.tv.MainActivity}
```

### 2. 一键解除接管、切回小米原厂桌面（PatchWall）
因为原厂桌面 `com.mitv.tvhome` 全程完好保留在系统中，若想随时恢复原厂桌面，仅需移除无障碍服务绑定并启动 `com.mitv.tvhome`：
```bash
adb shell settings put secure enabled_accessibility_services ""
adb shell am force-stop app.orchard.tv
adb shell am start -n com.mitv.tvhome/.activity.MainActivity
```
