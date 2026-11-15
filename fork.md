# Aves Miuix Fork

本项目基于 [deckerst/aves](https://github.com/deckerst/aves)，目标是在跟随上游功能的同时提供 Miuix 风格界面和适合个人使用的构建产物。

执行细则以 [`AGENTS.md`](AGENTS.md) 为准；本文件只记录当前项目形态、技术边界和任务记录。

## 当前功能

- 应用 ID：`io.github.baicha.aves`；类包名继续使用上游的 `deckers.thibault.aves`。
- 应用名：`Aves Miuix`。
- 默认启用 Miuix 皮肤，同时保留「Miuix 界面」开关以回退到 Material。
- Miuix 下使用常驻底栏和分页导航壳，保留各标签页状态，并支持底栏靠左、居中、靠右。
- 抽屉、设置页、图片信息页、顶栏、弹窗、菜单和提示条使用 Miuix 视觉。
- 修复了设置页展开后滚动瞬移、图片元数据展开空白、标签页滚动串扰、抽屉滚动带动底栏等问题。
- Android TV 布局已禁用；上游 TV 代码保留但不会进入。
- 自定义字体功能已完整撤回，当前没有对应源码或设置项。

## 技术边界

- Miuix 外观优先在皮肤层和 `settings.useMiuixUi` 分支内实现。
- 关闭 Miuix 后，Material 路径尽量保持上游行为和尺寸。
- 全局例外仅限应用身份、品牌名称、打包方式、Release 配置和 Android TV 禁用。
- Miuix 底栏必须复用上游底栏的占位高度，不应使页面整体位移。
- 分页壳仅用于 Miuix、非 TV、主模式的界面。
- 修改分页壳时必须继续保证页面路由身份、独立滚动控制器和标签状态互不串扰。
- `plugins/flutter_miuix` 是 vendored 依赖；升级时先替换源码，再重新应用 `material_ui` 导入和依赖约束补丁。
- 对上游文件的修改应保持窄范围、可识别、易合并；上游发生文件移动时按新结构迁移补丁。

## 构建与产物

构建 Release `arm64-v8a`：

```powershell
$env:BAICHA_ABIS = "arm64-v8a"
flutter build apk --release --flavor libre --target-platform android-arm64 -t lib/main_libre.dart
```

`versionName` 和 `versionCode` 不为二开改动单独递增；同步上游时跟随上游版本。

APK 文件名：

```text
aves-miuix-<versionName>-arm64-v8a-<本次改动摘要>-<feature-commit-id>.apk
```

APK 和构建产物不进入 Git。

## 上游同步

- 仅在用户明确要求时同步。
- 先检查共同祖先到 `upstream/develop` 的增量，再处理冲突。
- 锁文件冲突以重新生成解决，不手工拼接。
- 同步后重新验证应用身份、Miuix 集成、分页壳、TV 禁用和 Release 构建。
- 不向上游提交 PR。

## 任务记录

### 2026-11-11 22:34 (Asia/Shanghai) — 二开文档与规则重构

- 旧开发记录和本地环境备忘已移出仓库，不再参与项目维护。
- 新建精简的 `fork.md`，仅保留当前功能、技术边界、构建规则、同步规则和后续任务记录。
- 新建 `AGENTS.md`，固定任务规划、构建、本地提交、禁止主动推送/同步以及敏感信息保护等约定。
- 新约定取代此前关于提交时机、GitHub 推送和 APK 命名的旧约定。
- 功能提交：`8ad4e145f`。
- Release arm64 构建通过；`versionName=1.15.8`、`versionCode=182`、包名 `io.github.baicha.aves`，APK 仅包含 `arm64-v8a`，V2 签名验证通过。
- APK：`aves-miuix-1.15.8-arm64-v8a-文档规则重构-8ad4e145f.apk`，81,749,242 字节，SHA-256 `44D961B2495A2E54A7EF2D73C22A204342069896CEE6B77EAAE311374D16B973`。
- 本次未主动同步上游，未推送 GitHub。

### 2026-11-16 02:48 (Asia/Shanghai) — 同步上游至 b6a817897

- 上游新增 44 个提交、193 个文件变化；应用版本更新为 `1.15.10+184`。
- 解决 Release 工作流和 lock 文件冲突。三个 flavor 的依赖均已重新生成，根工作区保持 Libre 配置。
- 上游已将资源管理器拆分为 `explorer/page.dart` 与 `body.dart`；已删除旧 `explorer_page.dart`，并把分页壳内不重复挂载底栏/抽屉的逻辑迁移到新页面，相关测试引用同步更新。
- 自动质量检查继续保持手动运行；Release 工作流继续只发布 Libre arm64 APK。
- 品牌脚本重新执行，119 个本地化/Android 字符串文件保持 `Aves Miuix`；全部 ARB 通过 JSON 校验。
- 验证：`flutter analyze --no-pub` 无问题；主项目 127 项测试和 vendored `flutter_miuix` 69 项测试全部通过。
- 构建警告：上游 Firebase 插件仍自行应用 Kotlin Gradle Plugin，当前构建成功，但未来 Flutter 版本将要求迁移。
- 同步提交：`18995f4`。
- APK：`aves-miuix-1.15.10-arm64-v8a-同步上游更新-18995f4.apk`，82,555,635 字节，SHA-256 `EBF12D3CD9C1B0424347133A7017E0EF470116EFC7F44AE54C2C1A6A306FC48E`。
- 包名 `io.github.baicha.aves`、`versionName=1.15.10`、`versionCode=184`、仅 `arm64-v8a`，V2 签名验证通过。
- 本次未推送 GitHub，未向上游提交 PR。
