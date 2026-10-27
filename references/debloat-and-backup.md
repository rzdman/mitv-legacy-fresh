# 全量离线备份、10 项系统冗余包精简与桌面图标排雷指南

## 一、第一铁律：卸载前必须全量离线备份 APK

在 Android 6.0.1（API 23）上，由于系统不支持 `cmd package install-existing <pkg>`，**任何 `pm uninstall -k --user 0 <pkg>` 操作前，必须将该包在电视上的原始 APK 拉取到电脑本地目录（`backup/apks/`）保存**。

### 1. 注意区分「出厂系统路径」与「升级覆盖路径」
部分系统预装应用（如 `com.xiaomi.voicecontrol` 小爱同学、`com.xiaomi.mitv.appstore` 应用中心）在电视联网运行过程中曾自动升级到 `/data/app/<pkg>-1/base.apk`。
* 当对其执行 `pm uninstall -k --user 0 <pkg>` 时，Android 6.0 可能会先移除 `/data/app/` 下的升级包，或直接对 `user 0` 标记卸载。
* **正确备份姿势**：
  1. 先执行 `adb shell pm path <pkg>` 获取当前生效的 APK 路径；
  2. 若路径位于 `/data/app/`，除了备份 `/data/app/.../base.apk` 到本地与 `/sdcard/backup_apks/` 外，还应在 `/system/app/` 或 `/system/priv-app/` 中查找其出厂原始 APK 一并备份；
  3. 卸载后务必复查 `adb shell pm list packages | grep <pkg>`：若因为退回 `/system` 基线版而仍在列表中，再补执行一次 `adb shell pm uninstall -k --user 0 <pkg>` 即可彻底从当前用户移除。

### 2. 单包与全量无损回滚命令
由于 `/system` 分区仍保留有同签名记录，或本地存有原始签名 APK，回滚任意系统包只需执行：
```bash
# 方式 A：直接从电脑本地备份回滚安装到 user 0（允许降级 -d、覆盖 -r）
adb install -r -d --user 0 backup/apks/<pkg>.apk

# 方式 B：推送至电视 /data/local/tmp 后安装
adb push backup/apks/<pkg>.apk /data/local/tmp/restore.apk
adb shell pm install -r -d --user 0 /data/local/tmp/restore.apk
adb shell rm -f /data/local/tmp/restore.apk
```

---

## 二、10 项实测安全可精简系统包清单（`MiTV4-ANSM0`）

以下 10 个系统包在 `MiTV4-ANSM0`（Android 6.0.1）上实测移除后，**完全不影响系统中文设置、Wi-Fi 网络、HDMI 信号源切换、蓝牙遥控器连接、系统自带播放器硬解及投屏功能**：

### 第一批：8 项核心广告、OTA 升级、遥测统计、推送与商城组件（必删）

| 序号 | 包名 (`package`) | 组件名称与作用 | 实测风险与收益 |
| :---: | :--- | :--- | :--- |
| 1 | `com.miui.systemAdSolution` | **小米系统广告解决方案**（开屏/贴片/屏保广告核心引擎） | 必删；移除后配合锁死 `/sdcard/miad` 彻底根除系统广告 |
| 2 | `com.xiaomi.mitv.upgrade` | **系统固件 OTA 升级服务** | 必删；防止后台静默下载固件包占满存储或升级后复活广告 |
| 3 | `com.miui.tv.analytics` | **MIUI TV 行为分析与遥测上报** | 必删；减少后台高频网络唤醒与 CPU 占用 |
| 4 | `com.xiaomi.statistic` | **小米全局埋点统计服务** | 必删；切断后台隐私与状态上报 |
| 5 | `com.xiaomi.mitv.tvpush.tvpushservice` | **小米电视消息推送服务** | 必删；消除右下角营销弹窗与后台长连接 |
| 6 | `com.mitv.cloudcontrol` | **云控策略同步服务** | 必删；防止云端下发配置强行开启广告位或干预桌面 |
| 7 | `com.mitv.shoplugin` | **商城购物插件** | 必删；纯营销插件 |
| 8 | `com.xiaomi.gamecenter.sdk.service.mibox` | **小米游戏中心 SDK 后台服务** | 必删；不玩小米内置渠道游戏完全无用 |

### 第二批：2 项高内存/高存储占用的系统交互组件（按需确认后精简）

| 序号 | 包名 (`package`) | 组件名称 | 实测内存 (RAM) 占用 | 实测 `/data` 存储占用 | 说明与取舍建议 |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 9 | `com.xiaomi.voicecontrol` | **小爱同学（语音助手）** | 常驻 **~70 MB PSS** (`69,961 KB`) | `/data/app` 约 **61.6 MB** + 数据 **12.5 MB** | 2GB 内存电视的头号内存大户！若平时不用遥控器语音键，强烈建议卸载，立省 70MB 内存与 74MB 存储 |
| 10 | `com.xiaomi.mitv.appstore` | **小米应用中心（应用商店）** | 常驻 **~23.5 MB PSS** (`23,551 KB`) | `/data/app` 约 **18.9 MB** + 缓存 **193 MB** | 会在 `/sdcard/Android/data/com.xiaomi.mitv.appstore` 堆积近 200MB 推广 APK 缓存；装第三方软件直接用 ADB 或文件管理器即可，建议卸载 |

---

## 三、严禁触碰的系统核心白名单（红线）

在 Android 6.0.1 的 `MiTV4-ANSM0` 上，**绝对禁止卸载或改动**以下包：
* `com.mitv.tvhome`：**原厂桌面（PatchWall）与儿童模式宿主**（在 Android 6.0 上必须保留作为底层兜底，由 `Aerial` 无障碍服务无损接管，卸载会导致异常）
* `com.xiaomi.mitv.settings`：**系统中文设置**（Wi-Fi、蓝牙、图像声音、ADB 开关均在此包中）
* `com.xiaomi.mitv.systemui`：**系统 UI 与音量条/通知栏**
* `com.mitv.tvplayer` / `com.xiaomi.mitv.mediaexplorer`：**系统底层硬解播放器与媒体浏览**
* `com.android.packageinstaller` / `com.android.defcontainer`：**软件包安装器**（删掉后无法安装任何 APK）
* `com.xiaomi.mitv.smartshare` / `com.xiaomi.miplay` / `com.hpplay.*`：**无线投屏与米联组件**

---

## 四、广告残留目录清理与只读权限锁死

卸载 `com.miui.systemAdSolution` 与 `com.xiaomi.mitv.appstore` 后，执行以下命令清理约 **200 MB+** 广告缓存并锁死广告目录防止再生：

```bash
adb shell "
  rm -rf /sdcard/miad/* /sdcard/miad/.* 2>/dev/null
  rm -rf /sdcard/Android/data/com.miui.systemAdSolution/* 2>/dev/null
  rm -rf /sdcard/Android/data/com.xiaomi.mitv.appstore/files/* 2>/dev/null
  mkdir -p /sdcard/miad /sdcard/Android/data/com.miui.systemAdSolution
  chmod 000 /sdcard/miad
  chmod 000 /sdcard/Android/data/com.miui.systemAdSolution
"
```

---

## 五、常见排雷：为什么桌面上的「儿童模式」点进去像一个独立儿童应用？

在 `Aerial` 桌面上，用户常会看到一个叫 **「儿童模式」** 的图标，点进去后呈现出完整的卡通 UI（儿歌、动画片推荐等），容易误以为是某个未卸载的独立第三方儿童 APP。
* **技术真相**：通过 `dumpsys window windows | grep mCurrentFocus` 实测可知，点击「儿童模式」后打开的 Activity 是：
  `com.mitv.tvhome/com.mitv.tvhome.shaoer.ChildrenHomeActivity`
* **原理解析**：它**不是独立 APK**，而是小米原厂桌面 `com.mitv.tvhome` 在 `AndroidManifest.xml` 中额外注册的一个带有 `LAUNCHER` Intent Filter 的子入口（Activity Alias）。因为我们保留了 `com.mitv.tvhome` 作为安全兜底，`Aerial` 扫描所有桌面入口时就会把它列出来。
* **处理方法**：切勿因此去卸载 `com.mitv.tvhome`！只需在 `Aerial` 桌面上选中「儿童模式」图标，**长按遥控器「确定键」（或按「菜单键」），选择「隐藏应用」**，即可从桌面上干净隐藏，平时也完全不会在后台运行占内存。
