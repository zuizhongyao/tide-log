# 🛠️ App 开发技能手册 (appskill)

> 从「汐语 TideLog」从零到全功能上线的完整开发过程沉淀而来。
> 目标：下次做任何 App（不限 Flutter），照着这份手册走，**不再踩同样的坑，不再现查同样的问题**。
> 分为：核心心法 → 环境搭建 → 分层开发规范 → 测试策略 → 真机验证工具箱 → 踩坑索引 → 发布清单。

---

## 0. 核心心法（比任何代码都重要）

1. **分步推进，每步真机验证**：架构 → 数据层 → 核心算法 → 云服务 → UI，每步完成后必须在真机/模拟器上跑通并截图确认，再进下一步。纯代码层"看起来对"不算完成。
2. **算法写成纯函数**：不碰数据库、不碰网络，依赖全部通过参数注入（如注入 `today`）。测试才能确定、复用才有可能。
3. **单一数据源 + 变更订阅**：UI 只信一个状态层；状态层不只在自己的写操作后刷新，还要**订阅数据库变更流**——任何绕过它的写入（调试工具、云恢复、后台任务）都能让 UI 自动更新。
4. **依赖注入是可测试性的前提**：数据库目录、网络客户端、时间统统可注入。有接口才能有 Fake，有 Fake 才能测全链路。
5. **对行为存疑时先写测试验证，再下结论**：本次开发中 3 次"以为代码有 bug"，实测发现行为正确、错的是测试断言（另有 1 次真 bug 也是测试逼出来的）。
6. **文档只写真实存在的东西**：README 不吹没做的功能、不放假徽章。健康类 App 必须写免责声明。

---

## 1. 环境搭建 Checklist

```bash
# 一次性确认：SDK / JDK / adb 三件套的位置
flutter doctor -v          # 看 Android SDK、Java 是否被识别
flutter config --android-sdk <SDK路径>   # SDK 不在默认位置时必须配置
java -version              # 需要 JDK 17+
```

- **Windows + 国内网络必做镜像**（否则首次构建可能卡 40 分钟甚至失败）：
  - `android/gradle/wrapper/gradle-wrapper.properties` → 分发地址换腾讯云：
    `distributionUrl=https\://mirrors.cloud.tencent.com/gradle/gradle-<版本>-all.zip`
  - `android/settings.gradle.kts` → pluginManagement 与 dependencyResolutionManagement 的 repositories **最前面**加阿里云镜像：
    `maven { url = uri("https://maven.aliyun.com/repository/google") }`（public / gradle-plugin 同理），google()/mavenCentral() 兜底
  - Flutter 自身：`flutter config` 或环境变量指向 `storage.flutter-io.cn`
- 首次构建会自动下载 NDK / CMake / Platform（约 1-2GB），属正常现象；之后增量构建仅 20-30 秒。
- 模拟器 adb 端口速查：标准模拟器 `emulator-5554`，雷电 `127.0.0.1:5555`，MuMu `127.0.0.1:16384`。

---

## 2. 项目初始化标准动作

```bash
flutter create --org com.<你的域名> --project-name <蛇形名> --platforms android,ios <目录>
```

初始化后立刻做的 5 件事：

1. **应用名**：`android/app/src/main/AndroidManifest.xml` 的 `android:label`（默认是项目名，上架前必改）
2. **竖屏锁定（如需要）**：双保险——
   - Manifest 的 `<activity>` 加 `android:screenOrientation="portrait"`（启动瞬间生效，无横屏闪烁）
   - `main()` 里 `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])`（跨平台一致）
3. **minSdk 检查**：常用插件有下限要求（如 flutter_secure_storage 要求 23+）；Flutter 3.47 默认 24，老项目需检查 `android/app/build.gradle.kts`
4. **分层目录**：`core/`(主题/常量/工具) `models/` `services/` `algorithms/` `providers/` `views/`（按页面分子目录）+ `views/widgets/`(共享组件) + `views/debug/`(调试面板)
5. **主题语义色集中定义**：业务语义（如经期/排卵/易孕/安全）各配一个色值常量，全 App 只引用不散写——日历、圆环、图例自动一致

---

## 3. 依赖选型与兼容性避坑

- **选包先查三件事**：最近一次发布日期、是否有人接维护、最新版是不是 dev 版。
  血泪案例：`flutter pub add isar` 会拉到废弃的 `4.0.0-dev.3`（无可用生成器）；原 `3.1.0+1` 的生成器又与新版 Dart 不兼容。最终换社区分支 `isar_community`——API 完全一致，只改 import。
- **`flutter pub add` 分组执行**：常规依赖一组、代码生成器一组，失败时能快速定位是谁破坏了版本解析。
- 生成器与运行时必须**同版本同源**（isar_community ↔ isar_community_generator）。

---

## 4. 数据层设计规范

### 模型
- 每张表必带 `createdAt` / `updatedAt`（为同步预留，哪怕是本地优先应用）
- **枚举字段存固化 int code**，不存字符串、不依赖 enum.index（重排即毁）；字典用 `(code, label)` 常量表，只允许追加
- **null 语义 = 「未记录」**，与「记录了但没有」（false/0）严格区分——预测/统计算法依赖这个区别
- 日期一律归一化为**本地日历日 00:00**（工具函数 `normalizeDate`），入库存前、读出比对前都过一遍；"同一天"判断永远走 `isSameDay`
- 涉及唯一业务键（如"一天一条打卡"）时：唯一索引 + **upsert 复用旧 id**（同步场景 id 稳定是底线）

### 仓储 (Repository)
- 所有写操作统一在仓储层刷新 `updatedAt` + 同步元数据时间戳——调用方想忘都忘不了
- 提供三组方法：常规 CRUD、**原样批量写入**（云恢复用，保留 id/时间戳不刷新）、清空
- ⚠️ Isar 阶段机陷阱：`filter()` 不加条件是"死阶段"（无 sortBy/findAll）——全表排序用 `_collection.where().sortByDate().findAllSync()`
- ⚠️ 枚举类型的 getter 要加 `@ignore`，否则 isar 生成器报 "Enum property must be annotated with @enumerated"

### 自检
- 启动自检（debug 构建自动跑 CRUD 链路、结果上屏 + logcat）极有价值；**断言用相对计数**（`count == countBefore + 1`），绝对计数在库里有历史数据时必然误报

---

## 5. 算法层设计规范

- 纯函数 + 依赖注入（时间可注入）→ 测试完全确定
- 输入宽容：排序不限入参顺序（**函数内部先排，永不信任调用方顺序**——本项目统计图表全红柱 bug 的根因就是倒序列表算差值为负）
- 边界显式化：异常值阈值、上限窗口、冷启动默认值全部收进常量类，算法与 UI 共用唯一出处
- 输出携带"解释性元数据"（用了哪些样本、剔除了什么、数据成熟度等级）——统计页直接展示，算法不再是黑盒
- 测试覆盖六类：空输入冷启动 / 单样本 / 权重数学精确验证 / 异常过滤 / 边界滚动 / 端到端阶段判定

---

## 6. 服务层（网络 / 加密 / 同步）

- **网络客户端抽象成接口**：`abstract class OssClient` + dio 实现 + 测试 Fake。同步服务的上传/拉取/无操作全链路测试不需要真网。
- **签名类协议**（OSS V1 / AWS S3 等）：把 StringToSign 构造拆成独立静态方法再测，比整段 HMAC 对拍更稳。
- **加密文件格式**：魔数头 + base64(iv+密文)，读取时自动识别加密/明文；密钥由口令派生（SHA-256 → AES-256），每次独立随机 IV。
- **覆盖式同步策略**（单用户适用）：比较"本地最近修改时间 vs 云端数据时间戳"→ 新方整体覆盖旧方 / 相等零操作 / 恢复时原样写入（id/时间戳保留）并把本地判据对齐云端（恢复后即"已同步"）。
- 错误信息面向用户写中文（"云端备份已加密，请先配置加密密码"），异常类型自定义（`SyncException`），UI 直接展示。

---

## 7. UI 与状态管理

- 状态层职责：持有数据、产出派生结果（如预测）、提供全部写操作、暴露同步状态快照。
- **UI 永远从状态层读，不直连数据库**；状态层除了自身写后刷新，还要订阅数据库 watch 流（去抖合并刷新）。
- 长列表页面用 `IndexedStack` + 底部导航保状态；表单页 controller 在 dispose 里逐一释放。
- 打卡类交互：单选同值再点取消、多选 toggle、全空自动删记录（`hasAnyEntry` 语义）。
- 调试面板（`views/debug/`，仅 `kDebugMode` 可达）：数据 CRUD 演示、算法结果输出、凭证表单——**它是后续每一步的测试工具，值得当正式功能写**。
- 弃用 API 警告当场修（如 Flutter 3.31+ `Switch.activeColor` → `activeThumbColor`），不积累。

---

## 8. 测试策略

| 层 | 测什么 | 怎么测 |
|---|---|---|
| 算法 | 全部边界 | 纯函数 + 注入 today，宿主 VM 直接跑 |
| 数据层 | CRUD/upsert/时间戳/日期往返 | 临时目录注入 + `Isar.initializeIsarCore` 宿主库 |
| 服务层 | 加解密往返/签名格式/方向裁决/全链路 | Fake 网络客户端 + 真实 DB |
| 状态层 | 打卡语义/经期起止/同步快照 | 真实 DB + Provider 直测 |
| UI | 冒烟（四页可达、关键控件存在） | `pumpWidget` + DB 临时目录初始化 |

- 宿主跑 Isar 测试需要原生库：国内网络拉不到官方 CDN → 从 GitHub release 走镜像（如 `https://ghfast.top/https://github.com/...`）下载 DLL/SO **入库到 `test/native/`**，测试优先用本地、缺失才回退在线下载。
- 全量回归一条龙：`flutter analyze && flutter test`，每次改完必跑。

---

## 9. 真机验证工具箱（复制即用）

```bash
ADB="<SDK>/platform-tools/adb.exe"

# 连接与信息
"$ADB" connect 127.0.0.1:5555 && "$ADB" devices
"$ADB" shell getprop ro.build.version.release && "$ADB" shell getprop ro.product.cpu.abi

# 安装启动（注意顺序）
"$ADB" install -r app-debug.apk          # 偶发旧进程残留 → 先 uninstall 再 install
"$ADB" shell am force-stop <包名>
"$ADB" shell am start -n <包名>/.MainActivity
sleep 10                                  # 冷启动很慢，别省这一步

# 状态确认（白屏排查第一现场）
"$ADB" shell "dumpsys activity activities | grep mFocusedApp"
"$ADB" logcat -c && "$ADB" logcat -d | grep -iE "flutter" | grep -iE "error|exception|FATAL"

# 截图（Read 工具可直接看 PNG 验证 UI）
"$ADB" exec-out screencap -p > screen.png

# 交互：点按 / 滑动 / 返回
"$ADB" shell input tap <x> <y>
"$ADB" shell input swipe <x1> <y1> <x2> <y2> 300
"$ADB" shell input keyevent 4            # BACK
```

- Flutter 控件在 `uiautomator dump` 里通常**不可见**（语义未暴露）→ 直接截图目测坐标 tap。
- Git Bash 会把 `/sdcard` 转成本地路径（MSYS 路径转换）→ 用 `adb exec-out <cmd>` 直接输出，别写模拟器文件再 cat。

---

## 10. 踩坑索引（症状 → 解法）

| # | 症状 | 根因 | 解法 |
|---|---|---|---|
| 1 | `pub add` 拉到 dev 废弃版 / 生成器不可用 | 原包停维护 | 换社区分支；选型先查发布日期 |
| 2 | `Could not resolve annotation @Collection` | import 了不存在的包主文件 | 读包源码确认主 lib 文件名（isar_community 的主文件是 `isar.dart`） |
| 3 | Enum property must be annotated with @enumerated | 生成器把枚举 getter 当属性 | getter 加 `@ignore` |
| 4 | `sortByDate` isn't defined on QueryBuilder | Isar 阶段机：无条件 `filter()` 是死阶段 | `where().sortBy()` 或先加条件 |
| 5 | `Undefined name 'IsarAbi'` | 内部 typedef 未从主库导出 | 测试里 `import 'package:xxx/src/native/isar_core.dart'` |
| 6 | 下载原生库 `HandshakeException` | 国内网络阻断 | GitHub release 走 ghfast.top 等镜像，产物入库 |
| 7 | Gradle 下载 `Premature EOF` | 官方分发被墙 | 腾讯云 gradle 镜像 + 阿里云 maven（见 §1） |
| 8 | `Couldn't resolve the package 'xxx'` | 包名笔误（蛇形名带下划线极易错） | 写完 import 用 `grep -rn "package:简写/"` 自查；本项目犯过 3 次 |
| 9 | 启动白屏 / 应用不在前台 | install -r 旧进程残留；模拟器冷启动 1 分钟+ | uninstall 重装；`am start` 后等 10s+；查 `mFocusedApp` 与 logcat |
| 10 | 自检 FAIL 但功能正常 | 自检用绝对计数断言 | 相对计数（before+1） |
| 11 | 界面数据陈旧 | 写入绕过状态层 | 状态层订阅 DB 变更流（§7） |
| 12 | 图表颜色/数值全错 | 用了倒序列表做差值 | 函数内部先排序（§5） |
| 13 | `File has been modified since read` | sed 等外部方式改过文件 | 先 Read 再 Edit/Write |
| 14 | sed 改中文字符串吞引号/乱码 | sed 对 UTF-8 中文脆弱 | 中文/复杂改动用 Edit 工具或 python 单行脚本 |
| 15 | 代码出现占位/垃圾片段 | 长文件逐块打补丁时思路断裂 | **果断整文件重写**，不修补 |
| 16 | 后台构建日志一直是空的 | `2>&1 \| tail` 管道缓冲到结束才输出 | 后台任务输出全量日志，轮询 `tail 原始文件` |
| 17 | `selectedFontSize` 等参数报错 | 属性属于 Widget 不属于 ThemeData | 查对应 Theme*Data 的真实字段 |
| 18 | 弃用 API 警告（activeColor 等） | Flutter 迭代快 | 当场按提示改，不积累 |

---

## 11. 通用工程纪律（不限 Flutter）

- **每步交付物**：代码 + 分析零警告 + 测试通过 + 真机截图。四样齐了才算完。
- **改完必跑**：`analyze + test` 是最小回归；涉及 UI 的追加真机截图对比。
- **环境决策写进仓库**（镜像配置、minSdk、签名说明），不要只存在于聊天记录里。
- **降级方案先行**：在线依赖（原生库下载、云服务）都要有离线/本地回退路径。
- **给未来的自己留工具**：调试面板、自检、可注入的测试环境，都是下一分钟的排查利器。

---

## 12. 发布前 Checklist

- [ ] `android:label` 改为正式应用名；应用图标替换默认模板图
- [ ] release 签名 keystore 生成并配置 `key.properties`（**不入库**）
- [ ] `flutter build apk --release` 实测安装（debug 自检代码已用 `kDebugMode` 隔离）
- [ ] 隐私声明 + 免责声明上屏（健康类必需）
- [ ] 云端依赖项（OSS 等）用真实凭证走一遍完整闭环
- [ ] 落地页部署（静态托管），APK 产物放入下载目录
- [ ] 版本号：`pubspec.yaml` 的 `version` 与落地页展示一致
