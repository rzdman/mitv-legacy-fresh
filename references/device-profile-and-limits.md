# 目标机型软硬件档案与 Android 6.0 (API 23) 底层限制剖析

## 一、基准实测机型软硬件档案

本技能以 **小米电视 4 55英寸（`MiTV4-ANSM0`）** 为基准实测机型，同时适用于同代搭载 **Amlogic S905X (`gxbaby` / `t962`)** 或 **MStar** 芯片、运行 **Android 5.1 ~ 6.0.1（API 22 ~ 23，MIUI TV / PatchWall 早期版本）** 的老款小米电视（如小米电视 3s、小米电视 4 / 4A / 4C / 4X / 4S 早期批次、小米盒子 3 / 3s / 3c）。

| 维度 | 实测参数（`MiTV4-ANSM0`） | ADB 检测命令 |
| :--- | :--- | :--- |
| **品牌 / 产品型号** | Xiaomi / `MiTV4-ANSM0`（55 英寸 4K 华星光电 CSOT 面板） | `getprop ro.product.model` |
| **设备代号 / 主板** | `xmen` / Amlogic `gxbaby` | `getprop ro.product.device` / `getprop ro.board.platform` |
| **SoC 处理器** | Amlogic S905X 四核 ARM Cortex-A53 @ 1.51 GHz | `cat /proc/cpuinfo` |
| **内核与用户态 ABI** | 内核 `armv8l` (Linux 3.14.29)，**用户态为 32 位 `armeabi-v7a`**（仅支持安装 32位 APK，不支持 `arm64-v8a`） | `getprop ro.product.cpu.abilist` |
| **GPU 图形核心** | ARM Mali-450 MP（OpenGL ES 2.0，支持 4K H.265/VP9 10-bit 硬解） | `dumpsys SurfaceFlinger` |
| **运行内存 (RAM)** | 2GB LPDDR（系统总可用 `1663 MB`，含 `512 MB` ZRAM 交换分区） | `cat /proc/meminfo` |
| **机身存储 (ROM)** | 8GB eMMC（`/data` 用户分区共 `5.5 GB`，精简前已用 `2.3 GB` / 可用 `3.2 GB`；精简后已用 **`1.9 GB`** / 可用 **`3.7 GB`**） | `df -h /data` |
| **系统与 API 版本** | **Android 6.0.1 (API Level 23)**，编译号 `MHC19J` (`22.11.28.3390`)，安全补丁 `2017-04-01` | `getprop ro.build.version.release` / `getprop ro.build.version.sdk` |
| **无线网络** | 5GHz Wi-Fi（QCA9377 芯片，协商速率 260 Mbps） | `dumpsys wifi` |

---

## 二、为什么老款小米电视（Android 6.0）不能套用 Android 9+ (`tv-fresh`) 方案？

社区针对新款小米电视（Android 9+，如 `MiTV-ASTP0`）编写的改造脚本（如 `tv-fresh`）在 Android 6.0.1 固件上存在 **三大底层技术壁垒**，直接照搬会导致**无法回滚、主页键失灵或黑屏**：

### 1. 缺失 `cmd package install-existing`（直接卸载将导致无法免备份还原）
* **Android 9+ 行为**：执行 `pm uninstall --user 0 <pkg>` 后，可随时用 `cmd package install-existing <pkg>` 从 `/system` 分区重新注册恢复。
* **Android 6.0.1 (API 23) 限制**：Android 6.0 的 `pm` / `cmd` **尚未引入 `install-existing` 子命令**。一旦未备份就执行 `pm uninstall -k --user 0 <pkg>`，除非恢复出厂设置或手里有同签名 APK，否则无法在当前用户下直接还原。
* **本技能解法**：在卸载任何系统包前，先通过 `pm path <pkg>` 定位其在 `/system/app`、`/system/priv-app` 或 `/data/app` 中的真实 APK 路径，使用 `adb pull` **全量提取离线 APK 备份至本地电脑**。回滚时通过 `adb install -r -d --user 0 <本地备份.apk>`（或推送至 `/data/local/tmp/` 后执行 `pm install -r -d --user 0`）实现 **100% 双向无损还原**。

### 2. 固件锁死 `pm disable-user` 且无 `FallbackHome` 独立包（卸载原厂桌面必出故障）
* **Android 9+ 行为**：卸载原厂桌面 `com.mitv.tvhome` 后，用 `pm disable-user --user 0 com.android.tv.settings` 禁用兜底黑屏页即可切入第三方桌面。
* **Android 6.0.1 (API 23) 限制**：
  1. 小米 Android 6.0 固件在 `PackageManagerService` 中拦截了 shell 权限的 `pm disable-user`，调用直接抛出 `java.lang.SecurityException: Permission Denial: attempt to change component state from pid=..., uid=2000`；
  2. 系统内不存在 `com.android.tv.settings`，原厂桌面 `com.mitv.tvhome` 与系统深度耦合，直接卸载 `com.mitv.tvhome` 会导致开机黑屏或遥控器 HOME 键彻底失效。
* **本技能解法**：**严禁卸载 `com.mitv.tvhome`**。选用专门针对小米 Android 6.0 适配了 AppOps 与无障碍守护的开源桌面 **[Aerial](https://github.com/pengchujin/aerial-tv)**（`app.orchard.tv`），通过授予 `WRITE_SECURE_SETTINGS`、`GET_USAGE_STATS`、`SYSTEM_ALERT_WINDOW` 并绑定 `HomeGuardService` 无障碍服务，在保留原厂桌面的前提下实现 **零风险无损接管 HOME 键与开机桌面**。

### 3. 系统缺失 Java 8 `CompletableFuture` 与现代 SDK API（新版应用拒装或爬虫死锁）
* **Android 6.0.1 (API 23) 限制**：
  1. 开源桌面 `lesnolie/Tigris` 要求 `minSdk 28`（Android 9+），无法安装；
  2. 开源播放器 `FongMi/TV` 从 `v4.0.7` 后期提交起将 `minSdk` 提升至 `24`（Android 7.0+），最新版 `v5.8.4` 无法安装；
  3. Android 6.0 系统标准库缺失 API 24 才引入的 `java.util.concurrent.CompletableFuture`，导致部分未开启脱糖（Desugaring）的播放器（如 `影视仓`）在运行 TVBox 爬虫（如 `饭太硬` 玩偶哥哥 `csp_WoGGGuard`）时陷入线程死锁、屏幕无限转圈。
* **本技能解法**：
  1. 桌面选用支持 `minSdk 21` 的 `Aerial` 最新版（`v1.57`）；
  2. 播放器精准选用 `FongMi/TV` 官方最后支持 `minSdk 21` 的 32 位电视版 **`v4.0.7` (`versionCode=407`, `leanback-armeabi_v7a.apk`)**，其内置 Core Library Desugaring（Java 8 脱糖库），彻底解决 API 23 下「玩偶哥哥」点片死转圈问题。

---

## 三、精简优化前后性能提升实测对比（`MiTV4-ANSM0`）

| 性能指标 | 精简改造前（原厂状态） | 精简改造后（Aerial + 10项精简） | 提升幅度与实际体验变化 |
| :--- | :--- | :--- | :--- |
| **启用系统包总数** | 57 个 | **45 个** | 减少 **12 个** 后台常驻/唤醒包 |
| **`/data` 可用存储空间** | `3.2 GB`（已用 2.3 GB） | **`3.7 GB`（已用 1.9 GB）** | 净释放 **约 450 MB ~ 500 MB** 宝贵闪存空间 |
| **后台常驻内存释放** | 小爱同学 (`70 MB` PSS) + 应用中心 (`23.5 MB` PSS) + 广告/统计/推送 (`~60 MB`) 常驻 | **空闲可用内存稳定在 `715 MB ~ 886 MB`** | 释放 **约 150 MB+** 常驻物理内存，大幅降低 ZRAM 换页卡顿 |
| **开机与屏保广告** | 开机广告 + 桌面瀑布流广告 + 商城推荐 | **0 广告**（广告引擎移除 + `/sdcard/miad` 只读锁死） | 开机直达纯净应用网格，彻底杜绝后台偷下广告视频 |
| **遥控器与主页响应** | 按 Home 键回 PatchWall 瀑布流需等待海报重载（1.5~3秒） | **按 Home 键 `< 0.2 秒` 瞬回 Aerial 纯净桌面** | 遥控器方向键移动丝滑跟手，无焦点延迟 |
| **4K 点播（「玩偶哥哥」）** | `影视仓` 点击「玩偶哥哥」影片单核 25% CPU 死循环转圈 | **`FongMi v4.0.7` 点击影片 1~2 秒秒开详情页并呼出网盘扫码** | 完美播放夸克/UC 4K 原画网盘源 |
