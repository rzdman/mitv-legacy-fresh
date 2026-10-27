# mitv-legacy-fresh · 老款小米电视（Android 5.1 ~ 6.0.1）免 Root 焕新完全指南 & Agent Skill

> **专为 2016~2019 年上市的老款小米电视 / 小米盒子打造（实测机型：小米电视 4 55英寸 `MiTV4-ANSM0` / Android 6.0.1 / API 23 / 32位 `armeabi-v7a`）**
>
> 免 Root · 全量离线 APK 备份 · 100% 双向可逆回滚 · 零风险无损接管桌面 · 彻底解决 API 23 下 TVBox「玩偶哥哥」点片无限转圈问题

---

## 💡 为什么要做这个项目？（与 `tv-fresh` 的核心区别）

社区热门项目 [`tv-fresh`](https://github.com/wangrongding/tv-fresh) 为新款小米电视（**Android 9+ / API 28+**，如 `MiTV-ASTP0`）提供了优秀的改造方案。但如果你手头是一台运行 **Android 5.1 ~ 6.0.1（API 22 ~ 23）** 的早期经典机型（如 **小米电视 4 系列 `MiTV4-ANSM0`、小米电视 3s、4A/4C/4X 早期批次、小米盒子 3/3s/3c**），直接照搬 Android 9+ 的脚本会立刻踩中 **三大致命陷阱**：

| 对比维度 | `tv-fresh`（仅适用 Android 9+ 新款机型） | `mitv-legacy-fresh`（专为 Android 6.0 老款机型定制） |
| :--- | :--- | :--- |
| **1. 系统包还原机制** | 依赖 `cmd package install-existing <包名>` —— **该命令在 Android 7.0 (API 24) 才引入，Android 6.0 执行直接报错，一旦盲目卸载将无法直接还原！** | **卸载前全量提取离线 APK 备份 + `/system` 原始路径映射**：通过 `pm install -r -d --user 0` 实现单包/全量 **100% 无损可逆回滚**。 |
| **2. 换桌面防黑屏机制** | 直接卸载 `com.mitv.tvhome` 并用 `pm disable-user` 禁用 `com.android.tv.settings` —— **Android 6.0 固件底层锁死了 `disable-user`（报 `SecurityException`），且无 `com.android.tv.settings` 包，卸载原厂桌面会导致主页键失灵或黑屏！** | **保留 `com.mitv.tvhome` 不卸载 + 选用开源桌面 [Aerial](https://github.com/pengchujin/aerial-tv) (`v1.57`)**：通过 `GET_USAGE_STATS` 与 `HomeGuardService` 无障碍服务**零风险无损接管 HOME 键与开机桌面**，1 秒可切回原厂桌面。 |
| **3. 播放器与「玩偶哥哥」转圈死锁** | 直接安装最新版 `FongMi`（要求 `minSdk 24`，Android 6.0 根本装不上）；且 Android 6.0 缺失 Java 8 `CompletableFuture`，用 `影视仓` 点「玩偶哥哥」会触发 `.ProcessManager` 25% CPU 死循环无限转圈。 | 源码历史溯源提取官方最后支持 `minSdk 21` 的 **`FongMi/TV v4.0.7` (32位版)**，内置 Java 8 脱糖支持（Core Library Desugaring），配合 **游魂多仓**，实测「玩偶哥哥」详情页 **1~2 秒秒开**！ |

---

## 📊 基准实测机型档案与改造前后性能对比

### 1. 实测硬件与固件环境（`MiTV4-ANSM0`）

* **产品型号 / 代号**：小米电视 4 55英寸 `MiTV4-ANSM0`（代号 `xmen`，4K 华星光电 CSOT 面板）
* **处理器 (SoC)**：Amlogic `gxbaby`（S905X 四核 ARM Cortex-A53 @ 1.51 GHz）
* **图形核心 (GPU)**：ARM Mali-450 MP（OpenGL ES 2.0）
* **指令集架构 (ABI)**：内核 `armv8l` (Linux 3.14.29)，**用户态为 32 位 `armeabi-v7a`**（仅可安装 32 位 APK）
* **内存与存储**：`2 GB` LPDDR RAM（总可用 1663 MB，含 512 MB ZRAM）+ `8 GB` eMMC ROM（`/data` 分区共 5.5 GB）
* **系统版本**：**Android 6.0.1 (API Level 23)**，编译版本 `MHC19J` (`22.11.28.3390`)，安全补丁 `2017-04-01`

### 2. 精简优化前后实测对比

| 评估维度 | 改造前（小米原厂 PatchWall 状态） | 改造后（Aerial v1.57 + 10项精简 + FongMi v4.0.7） | 实际提升效果 |
| :--- | :--- | :--- | :--- |
| **启用系统包总数** | 57 个 | **45 个** | 砍掉 **12 个** 广告/遥测/语音/商城后台包 |
| **`/data` 可用存储空间** | `3.2 GB`（已用 2.3 GB） | **`3.7 GB`（已用 1.9 GB）** | 净释放 **约 450 ~ 500 MB** 闪存空间 |
| **常驻物理内存释放** | 小爱同学 (`70 MB` PSS) + 应用中心 (`23.5 MB` PSS) + 广告/统计/推送 (`~60 MB`) 常驻 | **空闲可用内存稳定在 `715 MB ~ 886 MB`** | 释放 **150 MB+** 常驻内存，告别 ZRAM 频繁换页卡顿 |
| **开机与系统广告** | 开机视频广告 + 瀑布流推荐位 + 屏保画报广告 | **0 广告**（移除 `systemAdSolution` + `/sdcard/miad` `chmod 000` 只读锁死） | 彻底杜绝后台偷下百兆广告视频 |
| **主页键与遥控响应** | 按 Home 键回瀑布流桌面需等待 1.5~3 秒重载海报 | **按 Home 键 `< 0.2 秒` 瞬回 Aerial 纯净网格桌面** | 方向键指哪打哪，无任何掉帧延迟 |
| **4K 网盘点播体验** | `影视仓` 点「玩偶哥哥」影片一直转圈无法进入 | **`FongMi v4.0.7` 点「玩偶哥哥」1~2 秒秒开详情页并呼出夸克/UC扫码** | 老电视满血流畅播放 4K 原画网盘片源 |

---

## 🤖 作为 AI Agent Skill 使用（推荐）

本仓库既是一份完整的技术文档与脚本工具集，也是一个标准的 **AI Agent Skill**（兼容 WorkBuddy / Claude Code 等支持 `SKILL.md` 的智能体）。

### 安装 Skill

```bash
# 克隆至全局 Agent Skills 目录
git clone https://github.com/rzdman/mitv-legacy-fresh.git ~/.workbuddy/skills/mitv-legacy-fresh
```

### 对话触发示例（复制即用）

```text
连上我的老款小米电视（IP：10.54.1.83），按 mitv-legacy-fresh 技能流程帮我做全面优化：
1. 先盘点电视软硬件状态，并把待精简的系统包全量备份到本地；
2. 安装最新版 Aerial 纯净桌面并完成主页键无损接管；
3. 清理系统广告、统计、OTA 升级、小爱同学和应用中心，锁死广告目录；
4. 安装兼容 Android 6.0 的 FongMi 影视 TV v4.0.7，配置游魂多仓并测试「玩偶哥哥」线路。
```

---

## 🛠️ 手动分步实操与原理解析

### Part 1 · 开启 ADB 与全量离线备份（防变砖底线）

1. **开启电视 ADB 调试**：
   * 电视进入「小米电视设置 → 关于 → 产品型号」，连按遥控器确定键 5~7 次开启开发者模式；
   * 返回「小米电视设置 → 账号与安全 → ADB 调试 → 允许」；
   * 电脑执行 `adb connect <电视IP>:5555`，在电视弹窗上点击「一律允许」。
2. **执行全量离线 APK 备份**：
   ```bash
   ./scripts/mitv_legacy_manager.sh backup <电视IP>
   ```
   > 脚本会自动将无障碍配置快照写入 `backup/settings_snapshot.env`，并将 10 个待精简系统包的 APK 提取到 `backup/apks/`。

---

### Part 2 · 10 项系统冗余组件精准精简与广告目录锁死

#### 1. 实测可安全移除的 10 个系统包清单

| 分类 | 包名 (`package`) | 组件说明与实测资源占用 |
| :---: | :--- | :--- |
| **必删（8项）** | `com.miui.systemAdSolution` | **系统广告核心引擎**（开屏广告、贴片广告、画报广告） |
| 必删 | `com.xiaomi.mitv.upgrade` | **系统固件 OTA 升级**（防后台偷下固件包或升级后广告复活） |
| 必删 | `com.miui.tv.analytics` | **MIUI TV 行为统计与遥测上报** |
| 必删 | `com.xiaomi.statistic` | **小米全局埋点统计服务** |
| 必删 | `com.xiaomi.mitv.tvpush.tvpushservice` | **小米电视消息推送弹窗服务** |
| 必删 | `com.mitv.cloudcontrol` | **云控策略同步服务** |
| 必删 | `com.mitv.shoplugin` | **商城购物插件** |
| 必删 | `com.xiaomi.gamecenter.sdk.service.mibox` | **小米游戏中心后台服务** |
| **可选高占用（2项）** | `com.xiaomi.voicecontrol` | **小爱同学语音助手**（实测常驻占用 **70 MB RAM** + **74 MB 存储**，不用语音必删） |
| 可选高占用 | `com.xiaomi.mitv.appstore` | **小米应用中心**（实测常驻占用 **23.5 MB RAM** + **193 MB 推广 APK 缓存**） |

> ⚠️ **注意**：像 `小爱同学` 和 `应用中心` 这类曾在 `/data/app/` 下升级过的系统应用，第一次执行 `pm uninstall -k --user 0` 只会卸载升级包并退回 `/system` 出厂基线版，需紧接着执行第二次 `pm uninstall -k --user 0` 才能从当前用户彻底移除（一键脚本已自动处理此逻辑）。

#### 2. 一键执行精简与只读锁死 `/sdcard/miad`

```bash
# 仅精简 8 项广告/统计/升级组件：
./scripts/mitv_legacy_manager.sh debloat <电视IP>

# 连同小爱同学、应用中心共 10 项全部精简（推荐，释放内存最大）：
./scripts/mitv_legacy_manager.sh debloat --all <电视IP>
```

#### 3. 常见排雷：为什么新桌面上有一个像独立 APP 的「儿童模式」图标？
* 点进「儿童模式」后抓焦点窗口可见：`com.mitv.tvhome/com.mitv.tvhome.shaoer.ChildrenHomeActivity`。
* 它**不是独立应用**，而是原厂桌面 `com.mitv.tvhome` 内部注册的一个子入口（Activity Alias）。因为我们在 Android 6.0 上必须保留 `com.mitv.tvhome` 作为系统兜底，切勿卸载它！只需在 `Aerial` 桌面上选中「儿童模式」，**长按确定键 → 选择「隐藏应用」**即可。

---

### Part 3 · 免卸载 PatchWall 的 Aerial 纯净桌面无损接管

在 Android 6.0.1 上，开源桌面 **[Aerial](https://github.com/pengchujin/aerial-tv)**（`app.orchard.tv`，最新版 `v1.57` 仅 2.8MB）专门针对小米电视 Android 6.0 适配了 `GET_USAGE_STATS` 前台检测与 `HomeGuardService` 无障碍接管：

```bash
# 自动下载最新版 Aerial (v1.57) 并完成权限授予与无障碍守护绑定
./scripts/mitv_legacy_manager.sh install-aerial <电视IP>
```

> **升级维护提示**：每次覆盖安装新版本 `Aerial` 后，Android 系统会自动重置该应用的无障碍服务开关。只需运行 `./scripts/mitv_legacy_manager.sh repair-launcher <电视IP>` 即可一键重绑守护。

---

### Part 4 · 攻克「玩偶哥哥」点片无限转圈：部署 FongMi v4.0.7 与多仓线路

#### 1. 为什么 Android 6.0 上用 `影视仓` 点「玩偶哥哥」会一直转圈？
通过实机 `logcat` 与线程堆栈逆向分析，查明三大根因：
1. **加固壳死循环**：`饭太硬` 仓库 `fty_spider.jar` 中的 `csp_WoGGGuard`（`libftyguard_v7.so`）检测到 `deviceSdk=23` 时强制走 `use legacy go proxy, deviceSdk=23` 分支拉起本地代理子进程，被 Android 6.0 SELinux 拦截后 `.ProcessManager` 线程陷入死循环，占满单核 **25% CPU**；
2. **缺失 Java 8 类库**：Android 6.0.1 (API 23) 缺少 API 24 才引入的 `java.util.concurrent.CompletableFuture`，导致未做完整脱糖桥接的播放器在并发解析网盘源时回调中断；
3. **残留配置冲突**：本地 `/sdcard/TVBox/ogthread.json`（120 线程）与过期夸克/UC Cookie 进一步加剧阻塞。

#### 2. 终极解法：安装 `FongMi/TV v4.0.7`（官方最后支持 `minSdk 21` 的版本）
* `FongMi/TV`（影视 TV，`com.fongmi.android.tv`）从 `v4.0.7` 之后的提交起将 `minSdk` 提升到了 `24`（Android 7.0+）。
* 经追溯源码 Git 历史，**`v4.0.7` (`versionCode=407`) 是官方最后支持 `minSdk 21`（兼容 Android 6.0.1）的最终版本**。
* 得益于 `FongMi/TV` 编译时内置了 **Core Library Desugaring（Java 8 脱糖库）** 以及非阻塞详情页渲染架构，换用 `FongMi/TV v4.0.7` 后，哪怕使用同一个 `🚀游魂┃饭太硬 -> 👽玩偶哥哥┃4K弹幕` 线路，**点击任意影片均可 1~2 秒秒开详情页并正常弹出夸克/UC 扫码登录二维码！**

```bash
# 一键下载安装 FongMi/TV v4.0.7 (32位电视版)、授予存储权限并清理冲突缓存
./scripts/mitv_legacy_manager.sh install-fongmi <电视IP>
```

#### 3. 注入 2026 实测高可用多仓接口
打开 `FongMi/TV` 进入「设置 → 点播」弹窗后，可通过手机扫码或直接执行以下命令向 `9978` 端口推送 **游魂多仓**：
```bash
curl -s -X POST "http://<电视IP>:9978/action" \
  --data-urlencode "do=setting" \
  --data-urlencode "name=游魂多仓" \
  --data-urlencode "text=https://www.iyouhun.com/tv/dc"
```
* 在「设置 → 点播」右侧：点击 **🕒 时钟图标** 可切换不同主仓库（`饭太硬`、`多多`、`王二小`、`肥猫` 等）；点击 **🏠 小房子图标** 可切换当前仓库内的站点（如 `👽玩偶哥哥┃4K弹幕`）。

---

## 🔄 Part 5 · 一键状态检查与 100% 无损回滚命令

所有操作均封装在 [`scripts/mitv_legacy_manager.sh`](scripts/mitv_legacy_manager.sh) 中，随时可单点或全量还原：

```bash
# 1. 查看电视当前桌面、内存、存储及 10 项精简包状态
./scripts/mitv_legacy_manager.sh status <电视IP>

# 2. 单独恢复某一个被精简的系统包（例如恢复小爱同学）
./scripts/mitv_legacy_manager.sh restore-pkg com.xiaomi.voicecontrol <电视IP>

# 3. 一键恢复全部 10 个被精简的系统包
./scripts/mitv_legacy_manager.sh restore-all-pkgs <电视IP>

# 4. 解除 Aerial 接管，一键切回小米原厂 PatchWall 桌面（加 --uninstall 同时卸载 Aerial）
./scripts/mitv_legacy_manager.sh restore-launcher <电视IP>

# 5. 一键将所有系统包与桌面 100% 恢复至改造前的原厂初始状态
./scripts/mitv_legacy_manager.sh restore-factory-state <电视IP>
```

---

## 📂 仓库目录结构

```text
mitv-legacy-fresh/
├── SKILL.md                                  # AI Agent Skill 核心指令与五阶段工作流定义
├── README.md                                 # 项目总览与完整实操技术文档
├── LICENSE                                   # MIT 开源许可证
├── scripts/
│   └── mitv_legacy_manager.sh                # 全自动备份、精简、桌面接管、播放器部署与回滚脚本
└── references/
    ├── device-profile-and-limits.md          # MiTV4-ANSM0 软硬件档案与 Android 6.0 三大底层限制剖析
    ├── debloat-and-backup.md                 # 离线备份机制、10项精简清单、白名单与儿童模式排雷
    ├── launcher-aerial-guard.md              # Aerial 桌面选型对比、无损接管与升级守护重绑指南
    └── streaming-fongmi-tvbox.md             # FongMi v4.0.7 溯源、9978端口注入与「玩偶哥哥」转圈死锁排查
```

## 📄 License

[MIT License](LICENSE)
