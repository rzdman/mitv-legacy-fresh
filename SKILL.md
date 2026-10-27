---
name: mitv-legacy-fresh
description: This skill should be used when debloating, optimizing, replacing the launcher, or configuring TVBox and FongMi streaming apps on legacy Xiaomi MIUI TVs and Mi Boxes running Android 5.1 to 6.0.1 (API 22-23, 32-bit armeabi-v7a, such as MiTV4-ANSM0, MiTV 3s/4A/4C/4X). It provides full offline APK backup, zero-risk Aerial launcher takeover without removing PatchWall, and fixes for Spider deadlocks on API 23.
agent_created: true
---

# 老款小米电视焕新改造技能 (`mitv-legacy-fresh`)

专为运行 **Android 5.1 ~ 6.0.1（API 22 ~ 23，32位 `armeabi-v7a`）** 的老款小米电视与小米盒子设计的免 Root 去广告、系统精简、纯净桌面无损接管、点播播放器适配与 100% 可逆回滚技能。

> **基准实测机型**：小米电视 4 55英寸（型号 `MiTV4-ANSM0`，代号 `xmen`，Amlogic S905X `gxbaby` 四核 Cortex-A53 @ 1.51GHz，Mali-450 MP GPU，2GB RAM + 8GB eMMC，Android 6.0.1 / API Level 23，编译号 `MHC19J`）。

---

## 核心技术前提（与 Android 9+ `tv-fresh` 的本质区别）

操作 Android 6.0.1 老款小米电视前，必须严格遵守以下三项底层限制（详见 [`references/device-profile-and-limits.md`](references/device-profile-and-limits.md)）：

1. **无 `cmd package install-existing` 命令**：Android 6.0 不支持免备份直接恢复已卸载系统包。执行任何 `pm uninstall -k --user 0` 前，**必须先从电视提取原始 APK 备份至电脑本地**，回滚时使用 `pm install -r -d --user 0` 从系统路径或本地备份重装。
2. **锁死 `pm disable-user` 且无独立 `FallbackHome` 包**：Android 6.0 固件拦截了 `pm disable-user`（报 `SecurityException`）。**严禁卸载原厂桌面 `com.mitv.tvhome`**，否则会导致开机黑屏或主页键失灵。必须保留 `com.mitv.tvhome`，采用 **Aerial (`app.orchard.tv`) + `HomeGuardService` 无障碍服务** 进行无损主页键接管。
3. **系统缺失 Java 8 `CompletableFuture` 且仅支持 32位 `armeabi-v7a`**：所有安装的 APK 必须为 **32位 (`armeabi-v7a`) 且最低系统要求不高于 API 23**。针对网盘线路（如「玩偶哥哥」）在 `影视仓` 上死转圈的问题，优先部署内置 Java 8 脱糖支持的 **`FongMi/TV v4.0.7`**（官方最后支持 `minSdk 21` 的版本）。

---

## 任务路由表（按需加载参考文档）

根据用户的具体指令，先读取对应的 `references/` 技术文档再执行操作：

| 任务场景 | 必读参考文档 | 核心说明 |
| :--- | :--- | :--- |
| **盘点电视软硬件 / 对比 Android 6.0 与 9+ 差异 / 性能提升总结** | [`references/device-profile-and-limits.md`](references/device-profile-and-limits.md) | 含 `MiTV4-ANSM0` 完整硬件档案、三大底层限制剖析及改造前后性能实测对比表 |
| **全量离线备份 / 去广告精简 / 卸载小爱同学与应用中心 / 识别「儿童模式」图标** | [`references/debloat-and-backup.md`](references/debloat-and-backup.md) | 含 10 项可精简包清单与内存/存储实测数据、核心白名单、`/sdcard/miad` 只读锁死及「儿童模式」Activity Alias 排雷 |
| **安装或升级 Aerial 纯净桌面 / 修复主页键接管 / 切回原厂桌面** | [`references/launcher-aerial-guard.md`](references/launcher-aerial-guard.md) | 含 `Aerial` (`v1.57+`) 安装、AppOps 权限、`HomeGuardService` + `RevivalListener` 绑定及覆盖升级重绑规范 |
| **安装 FongMi(影视TV) 或影视仓 / 配置多仓接口 / 解决「玩偶哥哥」点片转圈** | [`references/streaming-fongmi-tvbox.md`](references/streaming-fongmi-tvbox.md) | 含 `FongMi v4.0.7` (`minSdk 21`) 溯源下载、`9978` 端口自动注入游魂多仓、以及 API 23 下「玩偶哥哥」转圈三大根因修复 |

---

## 标准五阶段执行工作流

对一台未改造的老款小米电视执行全面优化时，按以下五个阶段顺序推进：

### 阶段 1：连接设备与软硬件盘点
1. 执行 `adb connect <TV_IP>:5555` 并确认 `adb devices` 状态为 `device`。
2. 运行 [`scripts/mitv_legacy_manager.sh`](scripts/mitv_legacy_manager.sh) `status <TV_IP>`，核对 Android 版本（确认是否为 API 22~23）、CPU ABI（`armeabi-v7a`）、`/data` 剩余空间及当前已启用系统包。

### 阶段 2：全量离线备份与回滚验证
1. 运行 `scripts/mitv_legacy_manager.sh backup <TV_IP>`，将无障碍设置快照保存至 `backup/settings_snapshot.env`，并将 10 个待精简系统包的原始 APK 提取至 `backup/apks/`。
2. 确认所有待卸载包的 APK 均已在本地生成备份文件后再进入下一阶段。

### 阶段 3：安装 Aerial 纯净桌面并完成无损接管
1. 运行 `scripts/mitv_legacy_manager.sh install-aerial <TV_IP>`（或升级后运行 `repair-launcher <TV_IP>`）。
2. 验证 `app.orchard.tv` 已获得 `WRITE_SECURE_SETTINGS`、`GET_USAGE_STATS`、`SYSTEM_ALERT_WINDOW` 权限，且 `HomeGuardService` 守护运行数为 `1`。
3. 发送 `adb shell input keyevent 3` 测试 HOME 键，确认 `mCurrentFocus` 落在 `app.orchard.tv/.MainActivity`。

### 阶段 4：系统去广告精简与目录锁死
1. 向用户列出待精简的 8 项核心广告/统计/升级/推送组件及 2 项可选高占用组件（`com.xiaomi.voicecontrol` 小爱同学占 70MB RAM、`com.xiaomi.mitv.appstore` 应用中心占 23.5MB RAM + 193MB 缓存）。
2. 获得用户确认后，运行 `scripts/mitv_legacy_manager.sh debloat [--all] <TV_IP>`。
3. 验证 `/sdcard/miad` 与 `/sdcard/Android/data/com.miui.systemAdSolution` 已被清空并设为 `chmod 000` 只读锁定。

### 阶段 5：安装点播播放器并注入多仓线路
1. 运行 `scripts/mitv_legacy_manager.sh install-fongmi <TV_IP>`，安装官方最后支持 `minSdk 21` 的 32位版 **`FongMi/TV v4.0.7` (`com.fongmi.android.tv`)**，授予读写存储权限并清理 `/sdcard/TVBox/` 下导致转圈的旧冲突配置。
2. 按照 [`references/streaming-fongmi-tvbox.md`](references/streaming-fongmi-tvbox.md) 的指引，通过内网 `http://<TV_IP>:9978/action` 注入实测稳定的 **游魂多仓接口**（`https://www.iyouhun.com/tv/dc`），并验证「玩偶哥哥」线路详情页秒开与扫码弹窗。

---

## 硬性安全守则与操作规范

1. **严禁触碰核心系统包**：绝不卸载 `com.mitv.tvhome`（原厂桌面，包含「儿童模式」子入口，在 Aerial 中隐藏图标即可）、`com.xiaomi.mitv.settings`（系统中文设置）、`com.xiaomi.mitv.systemui`、`com.mitv.tvplayer`、`com.android.packageinstaller` 及无线投屏相关组件。
2. **先备份后卸载**：在未生成本地 APK 备份前，绝不执行 `pm uninstall -k --user 0`。
3. **Aerial 升级必重绑守护**：每次使用 `adb install -r` 覆盖升级 `Aerial` 后，系统会自动解绑无障碍服务，必须立即执行 `scripts/mitv_legacy_manager.sh repair-launcher <TV_IP>` 重新激活 `HomeGuardService`。
4. **FongMi 版本锁定 `v4.0.7`**：切勿在 Android 6.0.1 电视上将 `FongMi/TV` 升级至 `v4.0.7` 之后的版本（`v5.x` 要求 `minSdk 24`，无法安装）。
5. **Android 6.0 截图与 UI 校验规范**：Android 6.0 的 `adb exec-out screencap -p` 会将 `\n` 转为 `\r\n` 损坏 PNG 头；截图时应统一使用 `adb shell screencap -p /sdcard/tmp.png && adb pull /sdcard/tmp.png`，并配合 `uiautomator dump` 获取精准控件坐标。
