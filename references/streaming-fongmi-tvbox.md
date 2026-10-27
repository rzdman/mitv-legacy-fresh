# 点播播放器适配、FongMi v4.0.7 溯源与「玩偶哥哥」转圈死锁排查实录

## 一、核心痛点：为什么在 Android 6.0.1 电视上用 `影视仓` 点「玩偶哥哥」会一直转圈？

在 `MiTV4-ANSM0`（Android 6.0.1，API 23，32位 `armeabi-v7a`）上使用最新版 **影视仓 TV 版 (`v6.2.8`, `com.huawei.himovceie`)** 时，选择「玩偶哥哥」线路（如 `饭太硬` 仓库中的 `👽玩偶哥哥`）点击任意影片，屏幕会一直显示加载圈转圈，无法刷出详情页与选集；而在其他高版本安卓电视上却正常。

通过 `logcat`、`top -H` 线程分析与 `jadx` 反编译排查，定位到 **三大底层根因**：

### 根因 1：`fty_spider.jar` 加固壳在 `deviceSdk=23` 下的 `.ProcessManager` 死循环（25% CPU）
* `饭太硬` 仓库的爬虫包 `fty_spider.jar` 内置了原生 32 位加固壳 `libftyguard_v7.so`（`csp_WoGGGuard`）。
* 当其检测到当前电视为 `deviceSdk=23`（Android 6.0.1）时，日志打印 `use legacy go proxy, deviceSdk=23`，强行拉起 `killall` 与本地代理子进程 `.ProcessManager`。
* 受限于 Android 6.0 SELinux 策略与权限隔离，子进程握手失败，`.ProcessManager` 线程陷入死循环，单线程吃满单核 **25% CPU**（四核 A53 满载一核），导致 `影视仓` 的 `detailContent()` 同步调用永远无法返回。

### 根因 2：Android 6.0.1 (API 23) 缺失 `java.util.concurrent.CompletableFuture`
* 现代网盘类爬虫（玩偶哥哥、木偶、闪电、奥秘等）在并发请求夸克网盘（Quark）与 UC 网盘分享接口时，大量使用了 Java 8（Android 7.0 / API 24 才内置）的 `java.util.concurrent.CompletableFuture`。
* `影视仓` 在 API 23 设备上未对该类提供完整的脱糖桥接，直接抛出 `NoClassDefFoundError: Failed resolution of: Ljava/util/concurrent/CompletableFuture;`，导致详情页 UI 回调链路中断，全屏 Loading 遮罩无法消失。

### 根因 3：本地残留旧版过高线程配置与过期网盘 Cookie
* 若电视 `/sdcard/TVBox/` 目录下残留旧版配置（如 `ogthread.json` 配置了 `120` 线程并发，以及过期的 `quark_cookie.txt` / `uc_cookie.txt`），爬虫在初始化详情页校验失效 Ticket（返回 `AUTH_ERROR:50051 Invalid service ticket`）时会发生阻塞。

---

## 二、终极解决方案：换用 `FongMi/TV v4.0.7`（官方最后兼容 Android 6.0.1 的版本）

### 1. 为什么 `FongMi/TV`（影视 TV）能彻底解决「玩偶哥哥」转圈问题？
1. **原生内置 Java 8+ Core Library Desugaring（脱糖库）**：`FongMi/TV`（`com.fongmi.android.tv`）是所有现代 TVBox 爬虫的官方上游标准宿主，编译时开启了 Android Gradle Plugin 的脱糖支持，自带 `j$ / CompletableFuture` 兼容实现，在 Android 6.0.1 上运行网盘爬虫不会抛出 `NoClassDefFoundError`。
2. **异步非阻塞详情页渲染**：`FongMi/TV` 点进影片后，在 **1~2 秒内先渲染详情页与选集列表**（`优汐智1`、`夸父原2` 等），再异步检查网盘登录态并弹出清晰的 UC/夸克扫码登录窗口，绝不卡死在转圈界面。
3. **原生支持多仓展开**：在 `FongMi/TV` 的「设置 -> 点播」中填入多仓地址（如 `https://www.iyouhun.com/tv/dc`），它会自动将多仓展开存入右侧「🕒 历史记录」按钮中，并可通过「🏠 小房子」按钮自由切换站点。

### 2. `FongMi/TV` 的 Android 6.0.1 (`minSdk 21`) 版本溯源与获取
* **版本分水岭**：`FongMi/TV` 最新版（`v5.8.4`）在 `gradle/libs.versions.toml` 中要求 `minSdk = "24"`（Android 7.0+），无法安装在 Android 6.0.1 上。
* 通过检索 `FongMi/TV` 官方源码 Git 提交历史：
  * **Commit `6f0d2b5a`（`2025-08-01`，`versionName "4.0.7"`，`versionCode 407`）** 与 **Commit `795669e1`（`versionName "4.0.6"`，`versionCode 406`）** 是 **官方最后支持 `minSdk 21`（兼容 Android 5.0 ~ 6.0.1）的版本**；
  * 紧随其后的 Commit `de786caa`（`2025-08-04`）将 `minSdk` 提升到了 `24`。
* **可直接下载的官方 32 位电视端 APK 地址**（GitHub Release 历史镜像）：
  ```bash
  # 下载 FongMi/TV v4.0.7 (versionCode=407, minSdk=21, 32位电视端 leanback-armeabi_v7a.apk)
  curl --http1.1 -sL -o fongmi_tv_4.0.7_armeabi_v7a.apk \
    "https://raw.githubusercontent.com/aaaafeng123/Release/ecd01a0/apk/release/leanback-armeabi_v7a.apk"
  ```
* **重要提醒**：安装 `v4.0.7` 后，若日后在应用内点击版本号提示有新版，**切勿升级**（高于 `4.0.7` 的版本在 Android 6.0.1 上会报 `INSTALL_FAILED_OLDER_SDK`）。

---

## 三、通过内网 `9978` 端口自动配置多仓接口

无论是 `FongMi/TV` (`com.fongmi.android.tv`) 还是 `影视仓` (`com.huawei.himovceie`)，启动后都会在电视本机监听 **`9978` 端口**（内网 Web 控制台 `http://<TV_IP>:9978`）。

### 1. 避免端口冲突与预授权限
若电视上同时安装了 `影视仓` 和 `FongMi/TV`，先强行停止另一个进程以释放 `9978` 端口，并授予读写存储权限（防止 `pm clear` 后丢失权限）：
```bash
# 清理旧版冲突线程配置与过期网盘 Cookie（可选，修复转圈遗留问题）
adb shell "rm -f /sdcard/TVBox/ogthread.json /sdcard/TVBox/*cookie*.txt 2>/dev/null"

# 授予存储权限
adb shell pm grant com.fongmi.android.tv android.permission.READ_EXTERNAL_STORAGE
adb shell pm grant com.fongmi.android.tv android.permission.WRITE_EXTERNAL_STORAGE

# 停止后台影视仓进程，确保 FongMi/TV 独占 9978 端口
adb shell am force-stop com.huawei.himovceie 2>/dev/null || true
adb shell monkey -p com.fongmi.android.tv -c android.intent.category.LEANBACK_LAUNCHER 1
```

### 2. 给 `FongMi/TV` 注入多仓配置地址
在 `FongMi/TV` 中，先通过按键或点击打开「设置 -> 点播」配置弹窗，然后通过 `POST http://<TV_IP>:9978/action` 推送配置并点击确定：
```bash
# 推送游魂多仓地址至 FongMi/TV 当前打开的设置弹窗
curl -s -X POST "http://<TV_IP>:9978/action" \
  --data-urlencode "do=setting" \
  --data-urlencode "name=游魂多仓" \
  --data-urlencode "text=https://www.iyouhun.com/tv/dc"
```

### 3. 给 `影视仓` (`com.huawei.himovceie`) 注入多仓配置地址（备用播放器）
若用户仍想同时保留 `影视仓 v6.2.8`（最新 32位版可通过 tvbox 社区镜像下载），需要注意：
* `影视仓` 的 `9978` 端口接收参数为 `do=api&url=<接口地址>`；
* 在 `影视仓` 上若要使用网盘线路，建议在左上角仓库列表中切换至 **`🚀游魂┃多多`**（使用纯 Dex 实现的 `duo_spider.jar`，不含 `ftyguard_v7.so` 死循环壳）。

---

## 四、2026 实测高可用配置接口源汇总

在注入接口前，建议先在电脑端用 `curl -A "okhttp/3.15" -sL <URL> | head -c 300` 验证是否返回合法 JSON：

| 类型 | 名称 | 接口地址 | 实测状态与说明 |
| :---: | :--- | :--- | :--- |
| **多仓總入口（首选）** | **游魂多仓** | `https://www.iyouhun.com/tv/dc` | ✅ **极速稳定**（内含饭太硬、多多、肥猫、王二小、小米、南风等十余个主力子仓，`FongMi/TV` 与 `影视仓` 均原生支持） |
| 单仓接口 | 游魂┃饭太硬镜像 | `https://www.iyouhun.com/tv/fty` | ✅ 稳定（绕过原域名 DNS 污染，在 `FongMi v4.0.7` 下玩偶哥哥秒开） |
| 单仓接口 | 游魂┃多多镜像 | `https://www.iyouhun.com/tv/duo` | ✅ 稳定（纯 Dex 爬虫，兼容性极佳） |
| 单仓接口 | 游魂┃王二小镜像 | `https://www.iyouhun.com/tv/wex` | ✅ 稳定（含玩偶哥哥、木偶等网盘站源） |
| 单仓接口 | 肥猫单仓 | `http://肥猫.net/tv` | ✅ 稳定（约 40 个站点，需携带 `okhttp` UA 访问） |
