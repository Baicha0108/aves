# Aves Miuix — fork 说明与上游同步指南

本 fork 在 [deckerst/aves](https://github.com/deckerst/aves) 的基础上做两件事：

1. **打包定制**：应用 ID 改为 `io.github.baicha.aves`（调试版 `.debug`）、只出 arm64-v8a 单包、应用名 `Aves Miuix`、接入 release 签名。
2. **Miuix 皮肤**：接入 [flutter_miuix](https://github.com/ChuxinNeko/flutter_miuix)（miuix 的 Flutter 移植），并在 设置 → 显示 里提供「Miuix 界面」开关，与原 Material 界面可随时切换。

## 第一原则：MD 界面必须与上游逐像素一致

> 关掉「Miuix 界面」后，应用看起来必须**和上游 Aves 完全一样**。
> 所有外观改动只能发生在 Miuix 这一侧（`settings.useMiuixUi == true` 的分支里）。

这条原则决定了两类写法，**新增改代码时必须遵守**：

| ✅ 允许 | ❌ 禁止 |
| --- | --- |
| 在 Miuix 分支里换颜色/圆角/排版 | 让**布局尺寸**依赖皮肤开关 |
| 给上游组件加**可选**参数，默认值等于上游行为（如 `floating_bar.dart` 的 `border`/`cornerRadius`） | 给共享组件加**必填**参数或改默认值 |
| 新增文件、新增 Miuix 专用组件 | 修改上游共享的主题数据（如 `bottomNavigationBarTheme` 的高度） |
| `if (settings.useMiuixUi) { ... }` 包住新分支 | 在共享路径上 `if (settings.useMiuixUi)` 返回**不同尺寸**的值 |

**踩过的坑（已修）**：`AppBottomNavBar.getHeightWithMargin()` 曾经在 Miuix 分支返回
`AvesMiuixBottomBar.barHeight + 28`（无手势条时 92dp），而上游公式是
`kBottomNavigationBarHeight + getMargin(safeBottomPadding).vertical`（72dp）。
后果：切到 Miuix 后底栏占位凭空高 20dp、整体上移，网格底部留白也对不上。
现在这个函数**不再读皮肤开关**，永远返回上游公式；Miuix 的胶囊只是在同一个槽位里居中绘制。
回归测试：`test/widget/nav_bar_height_test.dart`（断言两种皮肤下高度都等于上游公式）。

**Miuix 底栏位置可选（2026/10/27）**。

设置 → 导航 → 「Miuix 底栏位置」提供靠左、居中、靠右三个选项，默认居中，因此旧用户外观
不变。设置键为 `miuix_bottom_bar_alignment`，随 Aves 配置备份/恢复保存。

实现只改变 `AvesMiuixBottomBar` 内部 `Align` 的水平 alignment：底栏宽度、64dp 高度、
条目宽度、选中指示器、底部占位和滚动隐藏都保持原值。Material 路径不读取该设置，仍然是
上游通栏 `BottomNavigationBar`。靠左/靠右时额外保留 12dp 外侧间距；居中模式不受影响。
胶囊已占满可用宽度时，三个选项的视觉效果会相同。

**"MD 底栏比原版高"的真相（2026/10/10 查清：不是我们的问题）**。真机 MEIZU 20
（1080x2400 @450dpi，DPR 2.8125）上底栏底边距 **112px≈39.9dp**，手机里那个官方
`deckers.thibault.aves.libre` 1.15.5 却是 **22px≈8dp**。原因不在 MD 分支：

- 上游 develop 的 `MediaQueryData.safeBottomPadding`
  （`lib/widgets/common/extensions/media_query.dart`）= `max(viewPadding.bottom, viewInsets.bottom,
  systemGestureInsets.bottom, bottomDisplayCornerRadius)`。真机插桩实测
  `padding=0 / viewPadding=0 / viewInsets=0 / systemGestureInsets=32dp /
  displayCornerRadii 底角=35.9111dp(=101px)`；平台侧 `dumpsys display` 也确认四角 `radius=101`。
  → `safeBottomPadding = 35.9111dp` → `getMargin().bottom = max(8, 35.9111+4) = 39.9111dp = 112.25px`，
  与实测 112px 吻合。（会话里那条 `getHeightWithMargin` 分支已在上一步删掉，与此处无关。）
- 手机上那个官方 1.15.5 **还没有这套逻辑**：从官方 APK 解出的 `libapp.so`（**未混淆**，
  `CollectionLens`/`AvesEntry`/`AvesNavItem`/`AvesFloatingBar`/`AvesAppContentDecorator` 都在、
  计数与我们相同）里 `safeBottomPadding`/`getMargin`/`getHeightWithMargin` 出现 **0 次**，我们是 1 次。
- 而且 `git show upstream/develop:lib/widgets/navigation/nav_bar/nav_bar.dart` 与
  `.../common/extensions/media_query.dart` 证明这两处都是**上游自己的代码**，
  不在 `git diff upstream/develop HEAD` 的改动清单里 → **fork 一行都没碰**。
- MuMu 上"正常"是因为模拟器四角半径 0、无手势 inset → `safeBottomPadding = 0`。

**决定（用户 2026/10/10）**：不为对齐那个旧 release 去改共享公式，继续与上游 develop 保持一致；
手机上的官方版更新到含该逻辑的版本后两者自然相同。

**分页壳里每个页面必须看到自己的路由名（2026/10/10 修，Bug 1）**。
症状：在「媒体集」把网格缩放到 4 列后切到「相册」标签，相册的小合集也跟着变成 4 列；
重进软件必现，原版没有这个问题。

- 根因：`main_shell_page.dart` 只在 `AvesScaffold` **之外**包了一层
  `ShellTabScope(routeName: _items[_index].route)`，于是 `PageView` 里**所有**页面拿到的都是
  **当前激活标签**的 route。而 `filter_nav_page.dart:148` 构造 `FilterGridPage` 时没传
  `settingsRouteKey`，`filter_grid_page.dart:220` 的
  `settingsRouteKey: widget.settingsRouteKey ?? context.currentRouteName!` 就取到了「媒体集」的
  `/collection` → 相册页读 `tile_extent_/collection`（100 → 4 列）而不是自己的
  `tile_extent_/albums`（126 → 3 列）。
- 修法：**两层 scope**。外层**保留**（底栏 `_getCurrentIndex`/`_goTo`、抽屉
  `page_nav_tile.dart:41`/`collection_nav_tile.dart:47` 要的正是"当前激活标签"），
  另外在 `PageView` 的每个槽位里再包一层 `ShellTabScope(routeName: _items[index].route)`，
  让每个被 host 的页面永远看到自己的 route。
- 真机验证：修复后「相册」标签 3 列 / 瓦片 341px（= `/albums`=126），
  「媒体集」标签仍是 4 列 / 263px（= `/collection`=100）。
- 回归测试：`test/widget/shell_route_scope_test.dart`（两层 scope 的优先级 +
  `TileExtentController` 用页面自己的 route 取 extent）。
- 同类隐患（同一原因，一并修好）：`filter_nav_page.dart:147` 的
  `settings.getShowTitleQuery`、`chip_set.dart:194` 的排序/筛选偏好、
  `entry_set_action_delegate.dart:224`。
- 教训：往 shell 里加"按路由存取的设置"时，**不要用 `context.currentRouteName` 去标识页面自己**，
  它在壳内表示的是"当前标签"；页面自己的身份要从内层 `ShellTabScope`（或显式传参）拿。

**抽屉不再摧毁分页壳（2026/10/10 修，Bug 2）**。
症状：点抽屉里任何一项后"底栏功能异常"——不再常驻、切标签变成整页替换（丢滚动位置与页面状态），
而且**回不到分页壳**。

- 根因：抽屉所有入口最终都走 `pushAndRemoveUntil(route, (route) => false)`
  （`nav_item.dart` 的 `goTo` 在 `topLevel == true` 时用这个谓词，`_defaultTopLevel` 对
  `/collection` `/albums` `/countries` `/places` `/tags` `/explorer` 全返回 true；
  `collection_nav_tile.dart` 的 `_goToCollection` 也自己调了一次）。
  这个 `(route) => false` 把 **`MainShellPage` 自己**也移除了 → 落到上游式独立页面，
  底栏由该页自己的 `AppBottomNavBar`（`persistent: false`、无 `indexOverride`、包着
  `FloatingNavBar` + `Hero`）接管。此后点「所有媒体集」只会命中 `nav_bar.dart` 的
  就地 `setFilters` 分支，**再也 push 不出壳**，必须重启应用。
  真机证据：抽屉点「相册」后相册页 3 列 / 341px（= 它自己的 `tile_extent_/albums`=126），
  若仍在壳内应读 `/collection`=100 → 4 列 / 250px。
- 修法：新增**壳导航桥** `ShellNavigation`（`lib/widgets/common/providers/shell_tab_provider.dart`）。
  壳在 `initState` 里 `activate()`、`dispose` 里 `deactivate()`。
  - 为什么用**静态注册表**而不是 `InheritedWidget`：调用方还可能是**被 push 到壳之上**的路由
    （`/tags` 等以及它们自带的底栏），那些路由不在壳的 widget 树里，拿不到任何 scope。
  - `switchTo` 由壳实现：先 `popUntil` 回到壳，再按 route 找标签
    （`/collection` 用 `SetEquality` 匹配 `item.filters`，以此区分底栏里的
    「所有媒体集 / 收藏夹 / 视频」），需要时 `setFilters` 就地换筛选 + `animateToPage` 换标签。
  - 抽屉项被点时（壳存在）：底栏目的地 → 交给桥切标签；集合筛选（所有媒体集/最近添加/相机/
    下载/截图/回收站/相册）→ 切到 `/collection` 标签 + `setFilters`；非底栏页面
    （`/tags` `/countries` `/places` `/explorer`）→ **在壳之上 `push`**（壳保活）。
  - 那些 push 上去的页面会挂**自己**的一条底栏（`filter_grid_page.dart:160` /
    `explorer_page.dart:144`；它们不在壳的 widget 树里，所以 `hostedInShell == false`），
    但**观感与壳内一致、没有缺陷**：同一个 `AvesMiuixBottomBar`、同一条上游高度公式、
    同样的 `extendBody: true`，真机 dump 的按钮 bounds 逐像素相同
    （`x 96..984 / y 2175..2333`）。唯一差异是**选中项高亮会落到第 1 项**
    （`nav_bar.dart:84` 用 `_getCurrentIndex`，算不出 `/tags` 对应哪个底栏项就兜底 `: 0`）；
    点底栏项仍会经壳导航桥 `popUntil` 回壳再切标签。
    **上游同样如此**（上游这些页是 `pushAndRemoveUntil` 出来的独立根页面，走同一个
    `_getCurrentIndex`），所以这不是 fork 引入的差异，已确认无需修改。
  - 目标页面还没注册 collection 时（首帧前就点抽屉），筛选先存 `_pendingFilters`，
    等 `_registerCollection` 之后延期一帧再 `setFilters`。
- **第一原则**：MD 皮肤永远不挂载壳 → `ShellNavigation.current == null` →
  抽屉与底栏完全走上游代码路径。
- 回归测试：`test/widget/shell_navigation_test.dart`。
- 坑：组件测试要 `import 'package:material_ui/material_ui.dart'`（**不是** `flutter/material.dart`）。
  aves 的组件用的是 vendored `material_ui`，两边的 `Material` 是不同类型，
  用错会报 `No Material widget found ... ListTile widgets require a Material widget ancestor`。

**主页面壳的动态配置与退出（2026/10/25 修）**。

`MainShellPage` 不能再把底栏配置永久缓存在 `late final` 里。壳现在监听
`bottomNavigationActionsKey`：配置变化时安全重建 PageController、页面槽和
`ShellNavigation`，优先保留仍然存在的当前目标；当前项被删除时依次回退到首页目标、第一个
可托管标签。这样重排不会切错页，新增标签也不会因旧索引越界。

首页匹配使用 `route + filters + path`，合集和自定义资源管理器路径不会误落到同 route 的
第一个标签。Home/Search 等不可常驻托管的动作通过 `ShellNavigation.openOver()` 在壳上方
push，既保留壳，又避免 `pushAndRemoveUntil` 摧毁标签状态。

壳只允许在 Miuix、非 TV 布局、首页目标存在于底栏且至少一个标签可托管时运行。关闭
Miuix 或进入 TV 后，通过共享 `RouteAware` 等待上层设置页退出，再用当前位置的 route、
filters 和 path 执行 `pushAndRemoveUntil`，回到上游单页导航；因此 MD 不会再挂着
PageView 壳，TV 也不会同时出现 `TvRail` 和底栏。

**底栏配置恢复后自动重建分页壳（2026/10/27 修）**。

底栏全部删除时，分页壳会按上一节的安全退出逻辑退化为普通路由。旧实现没有反向流程：
重新加回底栏后，`MainShellPage` 已经销毁，自然收不到新的 `bottomNavigationActions`；
`HomePage` 的挂壳判断又只在启动初始化时执行，所以只能重启才会恢复滑动切页和常驻底栏。
表现为旧式整页替换、切换“相册”时底栏跟着路由一起移动。

- 独立页面上的 `AppBottomNavBar` 通过 `MainShellLifecycle` 登记当前
  `route + filters + path`；它比单纯记录 route 更准确，能恢复同一 `/collection`
  下的「所有媒体集 / 收藏夹 / 视频」以及自定义资源管理器路径。
- `AppRouteObserver` 增加当前 `PageRoute` 通知，`AvesAppContentDecorator` 同时监听
  底栏配置、页面路由和页面上下文。只有设置页退出、当前页确实属于新底栏、Miuix 已开启、
  非 TV 且 Main 模式时，才把普通路由替换为分页壳，避免打断设置或深链。
- 重建时把登记的目标作为 `MainShellPage.initialItem`，通过现有
  `preferredIndex` 精确选中原标签；再执行 `pushAndRemoveUntil` 清掉旧独立路由，避免
  同时存在两套导航状态。
- 回归测试覆盖 `2 项 → 0 项 → 2 项` 的恢复目标、上下文去重通知，以及路由观察器
  对 push/pop 的 current route 跟踪。

**Android TV 布局已禁用（2026/10/25，用户决定）**。

本 fork 只维护手机/平板界面，不继续适配 TV 侧栏及其与分页壳、设置页、查看器的组合分支：

- `settings.useTvLayout` 恒为 `false`，因此上游所有 `useTvLayout` 分支保持休眠；包括
  Leanback 设备和旧配置，一律进入普通界面。
- 设置 → 显示 不再展示「Android TV 界面」入口；原 `SettingsTileDisplayForceTvLayout`
  及其专用的确认框/回收站联动依赖一并删除。
- 启动 `sanitize()` 会移除旧的 `force_tv_layout` 偏好，设置导入或旧安装都不会留下
  看不见但仍可能被备份导出的 TV 模式状态。
- TV 相关上游代码没有被大范围删除，只由统一判定关闭。这样后续同步上游时冲突面最小，
  也不需要逐个页面移除 TV 分支。

**抽屉（侧边栏）改成 Miuix 卡片分组（2026/10/11，Miuix 侧）**。

需求（用户原话要点）：每个大块都要有圆角、块与背景要有对比（用默认色、KSU 那种观感）、
第二块（「所有媒体集」所在的类型书签块）随设置里的增删自动变高变矮、每个选项是"小块"、
选中态也要圆角且与大块边缘留很小的间距。

真机（MEIZU 20）实测出的"五个大块"：①头部（AVES MIUIX + 关于/设置）②类型书签
（所有媒体集 / 最近添加 / 收藏夹 / 视频 / 动图 / 动态照片，= `settings.drawerTypeBookmarks`）
③相册书签（相机 / 下载 / 截图）④页面书签（相册 / 地区 / 标签 / 资源管理器）⑤回收站。

规格（全部只在 `useMiuixUi == true` 时生效）：

| 项 | 值 |
| --- | --- |
| 卡片圆角 | 16dp（squircle，= `MiuixCard.defaultCornerRadius`） |
| 卡片外边距 / 卡片间距 | 左右 8dp / 8dp（取代上游的 `Divider` + 16dp 空隙） |
| 卡片上下内衬 | 4dp |
| 每个选项相对卡片内缩 | 4dp |
| 选中小块圆角 | 12dp（= 16−4，与卡片同心） |
| 选项内容内缩 | 12dp（图标从 16dp 右移到 24dp，用户已确认接受） |
| 卡片色 / 抽屉背景 / 选中色 | `surfaceContainer` / `background` / `secondaryContainer`（沿用，真机 `#E0E1F9`） |
| 头部 | 仍整宽（强调色继续铺满状态栏区域），只把**下面两角**圆 16dp |

- 新增 `plugins/aves_miuix/lib/src/widgets/miuix_drawer_section.dart`
  （`AvesMiuixDrawerSection`：`Padding(margin)` → `MiuixCard` → `Material(transparency)` →
  `Column(每项外包 Padding(itemPadding))`）。**卡片高度完全由内容决定**，所以在
  设置 → 导航 → 抽屉编辑器 → 类型 里增删选项后，块高自动跟着变。
- `lib/widgets/navigation/drawer/app_drawer.dart` 拆成两条组合路径：
  `_buildUpstreamItems`（**逐字复刻上游**，含 `Divider` 与 `SizedBox(height: 8)`）与
  `_buildMiuixItems`（卡片分组、无 `Divider`）；`_buildTypeTiles` / `_buildAlbumTiles` /
  `_buildPageTiles` 只产出 tile，分隔交给各自的 wrapper。`_buildHomeLink()` 改为可返回
  `null`（MD 路径用 `?? const SizedBox()` 保持原样）。
- 选中态圆角**没有碰任何 tile 组件**：只在抽屉那次 `ListTileTheme.merge` 里加 `shape`
  与 `contentPadding`（Miuix 给值、MD 传 `null`）。依据是 vendored `material_ui` 1.5.0
  `lib/src/list_tile.dart:1049`（`customBorder: shape ?? tileTheme.shape`）与
  `:1066-1070`（`Ink(decoration: ShapeDecoration(shape: ..., color: effectiveTileColor))`）——
  一次主题合并同时拿到圆角填充 + 圆角水波纹 + 内容内缩，因此
  `collection_nav_tile.dart` / `page_nav_tile.dart` 一行都不用改，
  `shell_navigation_test.dart` 也不受影响。
- **踩到的坑**：`MiuixCard` 的底色画在自己的 `DecoratedBox` 上，而 `ListTile` 的选中态/水波纹
  画在**最近的 `Material`** 上。中间隔着有底色的 `DecoratedBox` 时 Flutter 会直接断言
  `ListTile background color or ink splashes may be invisible. The ListTile is wrapped in a
  DecoratedBox that has a background color ... this DecoratedBox will hide those effects`，
  实际后果就是**高亮被卡片底色盖住**。修法：卡片内容外面再包一层
  `Material(type: MaterialType.transparency)`（dev 断言与真机观感同时解决）。
- 回归测试：`test/widget/miuix_drawer_section_test.dart` —— 卡片圆角/宽度内缩（8dp+4dp）、
  卡片色 = `surfaceContainer` 且 ≠ `background`（浅色与深色各一条）、空块不渲染、
  选中态形状 = `MiuixSquircleBorder(12)` 且色 = `secondaryContainer`、tile 内容内缩 12dp、
  以及上面那条"最近的 `Material` 祖先必须是透明 Material"的守护断言。
- 真机验证（MEIZU 20，2026/10/11）：抽屉量测 tile 左右内缩 34px（=12dp=卡片 8 + 项 4）、卡间 45px
  （=16dp=4+8+4），五块齐全（头部/类型 6 项/相册 3 项/页面 4 项/回收站），类型块随「动图」勾选增减
  整体上下移动 146px（恰好一行）；`use_miuix_ui=false` 与改动前基线的 MD 抽屉截图逐像素比对
  **主体 0 个像素不同**（仅屏幕右下角 44px 系统导航栏区域有差异）。用户真机验收通过。
- 后续微调（用户反馈，2026/10/11）：
  - **头部与第一块之间要留间距**：头部自己不是卡片（它是一条通栏的强调色区域，只圆下面两角），
    所以紧紧跟在它下面的那一块改用 `AvesMiuixDrawerSection.leadingMargin`
    （在默认外边距 `defaultMargin` 的基础上补 8dp 顶部），让这里的间距与卡片之间的 8dp 一致。
    回归测试断言「`leadingMargin.top == defaultMargin.bottom` 且 `defaultMargin.top == 0`」。
  - **头部按钮不要胶囊**：Miuix 下给 `OutlinedButtonThemeData` 加
    `shape: RoundedRectangleBorder(borderRadius: 12)`（MD 传 `null`），
    把 Material 3 `OutlinedButton` 的默认 `StadiumBorder` 换成方形圆角；
    常量 `_AppDrawerState._headerButtonRadius = 12`。

**长按多选失效：壳里所有标签页共用了同一条路由的 `PrimaryScrollController`（2026/10/11 修）**。

症状（用户报告：「长按多选删除无法触发」）：Miuix 皮肤下长按无法进入多选，MD 皮肤正常。

- 根因：`ModalRoute` 会给**每条路由**装一个 `PrimaryScrollController`
  （`flutter/lib/src/widgets/routes.dart:1199`），而 Aves 的页面都从它取网格控制器
  （`collection_grid.dart:259`、`filter_nav_page.dart:145`、`explorer_page.dart:65` …）。
  分页壳把多个目的地放在**同一条路由**的 `PageView` 里，于是被 host 的每个页面都把各自
  的 `ScrollPosition` attach 到**同一个**控制器上。`ScrollController.position` 只允许恰好
  一个 position（debug 断言 `ScrollController attached to multiple scroll views.`，
  release 下 `_positions.single` 抛 `Too many elements`），而 `offset` 就是
  `position.pixels`：长按选择手势里 `GridSelectionGestureDetector._getItemAt()`
  （`common/grid/selector.dart:204`）正好读 `scrollController.offset`，异常被框架吞掉 →
  **长按静默无反应**（连震动都没有，因为它在 `Feedback.forLongPress` 之前就返回了）。
- 现象吻合：第一个被构建的标签页（媒体集）长按正常，**之后**构建的标签页（相册/标签等
  过滤网格）长按失效；push 到壳之上的页面是独立路由 → 正常；分区标题的长按
  （`common/grid/header.dart:41`）不读控制器 → 正常。同理，各标签页的滚动位置此前也互相串。
- 修法：新增 `ShellTabScrollScope`（`lib/widgets/common/providers/shell_tab_provider.dart`）
  ——每个标签页自持一个 `ScrollController` 并用 `PrimaryScrollController` 下发，语义与
  `ModalRoute` 的「每路由一个」对齐；`main_shell_page.dart` 用它包住每个 `_ShellTab`。
  注意 `nav_bar.dart:136` 的 `PrimaryScrollController.of(context)` 只在
  `persistent == false` 时求值，壳里的底栏是 `persistent: true`，不受影响。
- 回归测试：`test/widget/shell_tab_scroll_scope_test.dart` —— 两个「标签页」必须拿到不同的
  控制器、`offset` 可读、滚动互不影响；同时固化了反例（不包 scope 时共用控制器、`offset`
  抛异常），避免以后有人把 scope 去掉。
- 真机验证（2026/10/11）：Miuix 下「相册」标签页长按相册卡片进入多选、媒体集网格长按照常，
  用户真机确认通过。排查用的分辨实验：Miuix（有壳）vs MD（无壳）、以及同一页里
  「读 scrollController 的长按」（卡片）vs「不读的长按」（分区标题）。

**抽屉滚动会带着底栏一起隐藏（2026/10/11 修）**。

症状（用户报告）：「侧栏打开时从下往上划，背后的底栏滑动隐藏效果也会被触发」，
并且「滑到最底下底栏会回正」——后者正好暴露了根因。

- 根因：壳的 hide-on-scroll 用的是**通知冒泡**，而监听器原先包在**整个 `AvesScaffold`** 外面
  （`main_shell_page.dart`）。`Scaffold` 把抽屉建在自己的子树里，所以抽屉的
  `SingleChildScrollView` 每次滚动都会把 `ScrollUpdateNotification` 冒泡到壳的
  `_onScrollNotification`，于是抽屉的 `delta`/`extentAfter` 被当成「页面在滚动」：
  往下滑 → `_barOffset` 增大（底栏下沉隐藏）；快到抽屉列表底部时命中
  `if (after < childHeight && delta > 0) next = min(current, after / childHeight)`
  → 底栏回正。用户看到的就是这条分支，说明喂给它的确实是**抽屉的**滚动指标。
- 为什么页面自己不会误触发：抽屉打开时，`DrawerController` 的遮罩是
  `ColoredBox`（`_RenderColoredBox` 的 behavior 是 `HitTestBehavior.opaque`，
  `flutter/lib/src/widgets/basic.dart:8430-8434`）＋只带 `onTap` 的 `GestureDetector`，
  所以页面的网格在抽屉打开期间收不到指针事件、不会滚动；MD 皮肤里底栏由页面自己用
  `FloatingNavBar(scrollController: PrimaryScrollController.of(context))` 驱动，只认页面控制器，
  也从来没有这个问题。
- 修法：把 `NotificationListener<ScrollNotification>` 从 Scaffold 外层**移进 `body`**，
  只包住 `PageView`（`main_shell_page.dart`，`ShellScaffoldScope` 的 child）——
  它只能看到被 host 页面的滚动。与「第一原则」一致：MD 皮肤根本不挂壳。

**设置页 / 图片信息页的分区卡片（2026/10/11，Miuix 侧）**。

症状（用户报告）：设置页各分区「完全是贴在一起的」、圆角偏小、不像 Miuix；图片信息页同样。

- 载体：这两个页面（以及关于/调试页）的分区卡片都是同一个 `AvesExpansionTile`
  （`lib/widgets/common/identity/aves_expansion_tile.dart`），它包着第三方 `ExpansionTileCard`
  （git 依赖 `expansion_tile_card`）。使用点：`lib/widgets/settings/settings_definition.dart:23`
  （设置页列表，`SettingsListView` 自带 `EdgeInsets.all(8)`）、
  `lib/widgets/viewer/info/metadata/metadata_dir_tile.dart:36`（图片信息页）。
- 根因：`ExpansionTileCard` **没有 margin 参数** → 卡片之间 0 间距（贴在一起）；
  包默认 `borderRadius = BorderRadius.all(Radius.circular(8.0))`（偏小）、
  `elevation` 0→2.0（展开时抬高 + 阴影）、`finalPadding` **只在展开时出现**
  （aves 原本传 `EdgeInsets.symmetric(vertical: 6.0)`）→「折叠时贴着、展开才有间距」。
- 修法（Miuix-only，全部在 `miuixTheme != null` 分支）：
  `AvesExpansionTile.miuixCardRadius = 16`（= `MiuixCardDefaults.cornerRadius`，与抽屉卡片一致）、
  `miuixCardGap = 8`（卡片外包 `Padding(only(bottom: 8))`，与抽屉一致）、`elevation: 0.0`
  （扁平、无阴影，和 `MiuixCard` 一样）、`finalPadding: EdgeInsets.zero`（间距不再随展开变化）
  ＋展开内容末尾补 `miuixCardBottomInset = 4`（内容不贴卡片圆角）。
  MD 路径显式写回包/上游取值（8dp / 2.0 / `symmetric(vertical: 6.0)`）且不加外层 padding
  → MD 逐像素不变。横向留白保持列表自带的 8dp（用户选的）。
- 回归测试：`test/widget/aves_expansion_tile_test.dart`（Miuix：16dp / 0 / `EdgeInsets.zero` /
  卡间 8dp 且展开后仍是 8dp；MD：8dp / 2.0 / `symmetric(vertical: 6.0)` / 卡间 0）。

**展开分区滚出 ListView 后瞬移（2026/10/23 修）**。

`ExpansionTileCard` 要求通过 `PageStorageKey` 保存展开状态，但此前只传了普通
`Key('tilecard-$value')`。ListView 回收屏外分区时，卡片状态被销毁；共享的
`expandedNotifier` 仍记录该分区已展开，而重建的卡片动画控制器从折叠值开始，导致展开
内容高度消失、列表 extent 变化，表现为滚动时整页突然跳动。

修法是在卡片外层加一个不可见的
`KeyedSubtree(key: PageStorageKey('tilecard-storage-$value'))`，同时保留原普通 `Key`
供测试驱动查找。回归测试位于 `test/widget/aves_expansion_tile_test.dart`：展开卡片滚出
缓存再回来必须恢复原高度（修复前 309dp → 60dp，修复后保持 309dp）。

这个状态恢复修复是必要的，但用户实测仍能触发设置页瞬移。进一步用真实
`SettingsMobilePage` 复现后确认，第二处问题来自 Miuix 卡片高度差异下的 ListView 懒加载
extent 重估：展开「显示」并慢速滑动时，`maxScrollExtent` 会从 561.14 临时降到 425、
再回到 493，而展开卡片本身始终是 537dp。设置页现在仅在 Miuix 下使用足够大的
`ScrollCacheExtent`，让 8 个分区一次性布局；Material 仍使用上游懒加载。回归测试为
`test/widget/settings_scroll_jump_test.dart`。

**元数据卡片展开后正文灰白、长度异常（2026/10/27 修）**。

上节的 `PageStorageKey` 同时成了卡片内 `SelectableText` 的最近存储标识。新版
`SelectableText` 会从该路径恢复内部滚动偏移，却读到了 `ExpansionTileCard` 写入的
`bool` 展开状态，触发 `type 'bool' is not a subtype of type 'double?'`；正文高度被撑到
约 100000px，表现为 Huffman/JFIF 等所有元数据展开后只有一大片灰色空白。

修法是在卡片正文外增加一个由 StatefulWidget 持有 bucket 的独立 `PageStorage`：
外层 `PageStorageKey` 只保存展开状态，正文内部的 `SelectableText` 使用另一套存储作用域。
这样既保留展开状态恢复，也不会改上游元数据排版或文字选择能力。

**自定义字体（2026/10/11 已按用户要求「完全回退」，以下仅存历史，代码已恢复原状）**。

- 需求（用户）：「能给软件添加自定义字体功能吗，要一个优雅的方案，破坏性的不行」；用户选定：
  入口放「显示」（两个皮肤都看得到）、字体**拷贝进应用私有目录**、先只支持 1 个字形文件。
- 方案（四步，全部 additive，**不改 Android/Kotlin**）：
  1. **选**：复用 Aves 自己的 SAF「打开文件」通道 —— `StorageService.openFile([mimeType])`
     （`lib/services/storage_service.dart:45`，实现见 `:219`，走 `deckers.thibault/aves/activity_result_stream`
     的 `{'op': 'openFile'}`）；Kotlin 侧 `android/app/src/main/kotlin/.../channel/streams/darttoplatform/ActivityResultStreamHandler.kt:47`
     与 `:187-211` 用 `ACTION_OPEN_DOCUMENT` + `CATEGORY_OPENABLE` + `setTypeAndNormalize(mimeType ?: MimeTypes.ANY)`，
     把文件字节流回 Dart，用户取消时回传空字节。
  2. **校验**：按 sfnt 魔数认 TTF/OTF/TTC（`OTTO`/`true`/`ttcf`/`0x00010000`/`0x00020000`），
     不认就提示「不是有效的字体文件」并**不落盘**。
  3. **存**：拷贝到 `getApplicationSupportDirectory()/fonts/custom_font`（用 `path_provider`，
     已加进 `flavors/pubspec_{libre,izzy,play}.yaml` 与根 `pubspec.yaml`）；设置里只存
     `custom_font_path` / `custom_font_name` 两个新键（已登记进 `lib/model/settings/settings.dart`
     的导入类型表）。**原文件只读，从不修改或删除**。
  4. **加载/应用**：启动时（`lib/widgets/aves_app.dart` 的 `_setup()`，紧跟 `settings.init`）
     调 `AvesCustomFont.restore()`；`lib/theme/custom_font.dart` 用
     `FontLoader('AvesCustomFont')..addFont(...)..load()` 注册字体；Material 侧在
     `lib/theme/themes.dart` 的 `_baseTheme` 传 `fontFamily: AvesCustomFont.fontFamily`
     （`material_ui` 的 `theme_data.dart:604-611` 会 apply 到 defaultTextTheme/primaryTextTheme）；
     Miuix 侧给 `AvesMiuixTheme` 加**可选** `fontFamily`，把 14 档 `MiuixTextStyles` 全部
     `.apply(fontFamily:)`（少数地方用 `DefaultTextStyle(style: textStyles.x)` 整份替换环境样式，
     只靠 `ThemeData.fontFamily` 传不下去）。两处传 `null` 时行为与改动前**完全一致** →
     MD 且未启用自定义字体时逐像素不变。
  - 设置项：`lib/widgets/settings/display/display.dart` 的 `SettingsTileDisplayCustomFont` +
    新的行组件 `lib/widgets/settings/common/tiles/action.dart`（`SettingsActionListTile`，
    Miuix 下渲染 `MiuixArrowPreference`，Material 下是 `ListTile`）。
- 非破坏性保证：文件缺失/损坏/加载失败 → 回落系统字体，设置项保留（可重选或清除）；
  「清除」= 删除私有副本 + 清空设置键。
- 已知边界：只换文字字体（图标、`monospace` 块、字幕自带字体不受影响）；单文件 →
  粗体/斜体由引擎合成或回退系统字体；`.ttc` 只取第一个面。
- 测试：`test/theme/custom_font_test.dart`（sfnt 魔数识别；用合成字体内建 `name` 表验证
  Windows UTF-16BE 与 Mac ASCII 取名；`fontFamily` 仅在 loaded 时非空）。

## 改动规模（截至接入 Miuix 主界面 + 设置页）

| 类别 | 文件数 | 行数 | 冲突风险 |
| --- | --- | --- | --- |
| 新增（vendor 库 + 皮肤包 + 新页面 + 测试） | 145 | — | **无**（纯新增，不碰上游文件） |
| 机械改名（`strings.xml` / `l10n/*.arb` 的应用名） | 116 | ~318 | 低（解决方式固定，见下） |
| 真实代码改动（上游文件里加 Miuix 分支/壳接线） | 28 | ~500 | 中（上游活跃区，冲突点集中在我们加的分支） |

## 新增的文件（不用管冲突，但更新时要重打补丁）

| 路径 | 说明 |
| --- | --- |
| `plugins/flutter_miuix/` | vendor 的移植库（136 文件）。相对上游有 **2 处补丁**，见 `scripts/baicha/repatch_flutter_miuix.sh` |
| `plugins/aves_miuix/` | 皮肤层：主题桥（`avesMiuixColors`）、`AvesMiuixTheme`、重新导出 miuix API、`AvesMiuixBottomBar`、`AvesMiuixDrawerSection`（抽屉卡片分组） |
| `lib/widgets/miuix/miuix_sample_page.dart` | 组件样张页（验收/参考用） |
| `lib/widgets/about/miuix_skin_entry.dart` | 关于页里的样张入口 |
| `test/widget/miuix_skin_test.dart` | 皮肤渲染 + 开关的组件测试 |
| `test/widget/shell_tab_scroll_scope_test.dart` | 壳内每个标签页必须有各自的 `PrimaryScrollController`（否则长按选择静默失效、滚动互相串） |
| `test/widget/miuix_drawer_section_test.dart` | 抽屉卡片分组回归测试：卡片圆角/内缩、卡片色与背景有对比、空块不渲染、选中态圆角小块、卡片内要有透明 `Material` |
| `test/widget/nav_bar_height_test.dart` | 底栏高度回归测试：MD 与 Miuix 都必须等于上游公式 |
| `test/widget/shell_route_scope_test.dart` | 分页壳路由作用域测试：内层 `ShellTabScope` 必须覆盖外层，页面按自己的 route 存取 extent |
| `test/widget/shell_navigation_test.dart` | 壳导航桥测试：抽屉项在壳存在时必须走桥（切标签 / 换筛选），不能自己 `pushAndRemoveUntil` |

## 改动的上游文件（28 个，冲突时照这张表处理）

| 文件 | 改动 |
| --- | --- |
| `android/app/build.gradle.kts` | 分离 `classPackage`/`appId`、去掉 `.libre` 后缀、ABI 过滤（`defaultConfig` + 打包层 `jniLibs.excludes`，可用 `BAICHA_ABIS` 覆盖）、release 签名 |
| `android/gradle.properties` | 加 `kotlin.incremental=false`（本机 Kotlin 增量缓存会报错） |
| `pubspec.yaml` / `flavors/pubspec_*.yaml` | workspace 加 `plugins/aves_miuix`、`plugins/flutter_miuix`；依赖加 `aves_miuix` |
| `flavors/pubspec_libre.lock` / `pubspec.lock` | 重新生成的锁文件（flavor 工作流） |
| `plugins/aves_model/lib/src/settings/keys.dart` | 新增设置键 `use_miuix_ui` |
| `lib/model/settings/defaults.dart` / `modules/display.dart` / `settings.dart` | 设置字段 `useMiuixUi`（默认 true）+ 导入表 |
| `lib/widgets/aves_app.dart` | 根 builder 挂 `AvesMiuixTheme`，Selector 增加 `useMiuixUi` |
| `lib/theme/themes.dart` | 主题层 Miuix 覆盖：`popupMenuTheme` / `snackBarTheme` / `bottomSheetTheme` / 两处 `dialogTheme` 底色 |
| `lib/widgets/settings/common/tiles/*.dart`（4 个） | 设置行 → `MiuixSwitchPreference` / `MiuixArrowPreference` |
| `lib/widgets/settings/display/display.dart` | 新增「Miuix 界面」开关 |
| `lib/widgets/common/identity/aves_expansion_tile.dart` | 设置分区卡片 Miuix 化 |
| `lib/widgets/common/bars/app_bar.dart` + `floating_bar.dart` | 顶栏扁平化（`floating_bar` 新增 `border`/`cornerRadius` 可选参数） |
| `lib/widgets/navigation/nav_bar/nav_bar.dart` | 底栏 → `AvesMiuixBottomBar`（KSU 式悬浮胶囊）；**占位高度仍用上游公式**，胶囊在槽位内居中 |
| `lib/widgets/navigation/main_shell_page.dart`（新增） | **分页壳**：`PageView` 承载底栏各目的地，底栏常驻 + 页面保活（KSU 式标签切换）；**两层 `ShellTabScope`**（外层=激活标签，内层=该页自己的 route）；**每个标签页一个 `ShellTabScrollScope`**（各自的 `PrimaryScrollController`，否则长按选择/滚动位置会跨标签页串）；并把 `ShellNavigation` 桥接给抽屉（切标签 / 就地换筛选 / `popUntil` 回壳） |
| `lib/widgets/common/providers/shell_tab_provider.dart`（新增） | 壳内向子树广播路由名；**两层**：外层给底栏/抽屉/TV 导轨，内层给页内按 route 存取的设置。另含**壳导航桥 `ShellNavigation`**（静态注册表，供抽屉与壳外路由调用）与 **`ShellTabScrollScope`**（每个标签页一个 `PrimaryScrollController`） |
| `lib/widgets/navigation/drawer/page_nav_tile.dart` | 壳存在时改走壳导航桥（切标签，或在壳之上 push 非底栏页面）；否则保持上游 `navItem.goTo` |
| `lib/widgets/navigation/drawer/collection_nav_tile.dart` | 同上：集合筛选 → 壳内 `/collection` 标签 + `setFilters`，而不是 `pushAndRemoveUntil` |
| `lib/widgets/common/extensions/build_context.dart` | `currentRouteName` 优先取壳广播（抽屉高亮、按路由的设置项因此不受壳影响） |
| `lib/widgets/home/home_page.dart` | `_getRedirectRoute` 在「皮肤开启 + main 模式 + 无深链」时返回分页壳（保留 HomePage 的全部初始化） |
| `lib/widgets/collection/collection_page.dart` | 在壳内时页面不再自己挂底栏（底栏归壳所有） |
| `lib/widgets/filter_grids/common/filter_grid_page.dart` | 同上（相册/标签/地点等列表页在壳内也不再自挂底栏与抽屉） |
| `lib/widgets/explorer/explorer_page.dart` | 同上（资源管理器页） |
| `lib/widgets/navigation/nav_item.dart` | 新增 `pageBuilder` / `isHostable`，供壳直接构建目的地页面 |
| `lib/widgets/navigation/nav_bar/nav_bar.dart`（分页壳部分） | `AppBottomNavBar` 新增 `indexOverride` / `onSelectedOverride` / `persistent`；`_goTo` 先问壳导航桥，壳外才走上游 `item.goTo` |
| `lib/widgets/navigation/drawer/app_drawer.dart` | 抽屉配色 + 头部标题；**Miuix 卡片分组**（`_buildMiuixItems` / `_buildUpstreamItems` 两条组合路径 + `_buildTypeTiles`/`_buildAlbumTiles`/`_buildPageTiles`）、头部下两角圆角、选中态圆角小块（`ListTileTheme` 的 `shape`/`contentPadding`，MD 传 `null`） |
| `lib/widgets/common/identity/aves_filter_chip.dart` | chip 容器色/描边 |
| `lib/widgets/dialogs/aves_dialog.dart` | 对话框底色/圆角/标题 |
| `lib/widgets/about/about_mobile_page.dart` | 插入样张入口 |
| `lib/l10n/app_*.arb` + `android/app/src/*/res/values*/strings.xml` | 应用名 `Aves Miuix`（含 welcomeMessage） |

## 同步上游流程

> ⚠️ **本仓库禁止用 `git rebase` / `git merge` 同步上游。**
> 这个 clone 的历史被压平过：fork 的 `develop`（`8b9265b7c`）与 `upstream/develop`（`88661560f`）
> 是**两个互不相关的 root commit**，没有共同祖先（`git merge-base` 返回空）。
> `git rebase upstream/develop` 会把我们整棵树当成新增内容重放，
> 结果是**每个文件都 add/add 冲突**。正确做法是把上游改动当 patch 应用（见下）。

> 最近同步（2026/10/27）：`upstream/develop` 已前进到 `77ae1fb75`（Aves 1.15.8 /
> Flutter 3.47.8）。上游增量 319 文件，包含 C2PA 元数据、新版 Android flag 资源和
> `material_ui` 1.8.0。相冲突的 Miuix 顶栏、设置分区卡片、多选设置行和锁文件已处理；
> 三套 flavor 锁文件均按 Flutter 3.47.8 重新生成。完整验证与产物记录见
> `aves-miuix-progress.md` 的「2026/10/27 — 同步上游 `77ae1fb75`」条目。

```bash
# 一条命令：拉上游 → 应用上游 diff（--3way）→ 重打品牌名 → 切 flavor → 分析/测试 → 出 arm64 包
scripts/baicha/sync_upstream.sh
```

手动等价步骤：

```bash
git fetch upstream develop

# 只取两棵树的差异。注意不要用 `git log develop..upstream/develop`：
# upstream/develop 是 root commit，range 语法会打印它那 1813 个文件的完整 diff。
git diff develop upstream/develop          # 先看差异有多大
git diff develop upstream/develop > /tmp/upstream.patch
git apply --3way /tmp/upstream.patch       # 3way 会在只被我们改过的那几个文件上自动合并

scripts/baicha/apply_brand_name.sh      # 上游若新增语言，重跑即可
cp flavors/pubspec_libre.yaml pubspec.yaml
"$FLUTTER_BIN" pub get                   # 上游若改了依赖，需要重新生成 flavors/*.yaml 与 *.lock
"$FLUTTER_BIN" test
BAICHA_ABIS=arm64-v8a "$FLUTTER_BIN" build apk --release --flavor libre \
  --target-platform android-arm64 -t lib/main_libre.dart
```

判断"我们和上游到底差多少"：`git diff --shortstat develop upstream/develop`。
（实测 2026/10 那次只有 **9 files changed, 154 insertions(+), 159 deletions(-)**。）

判断哪些上游改动会和我们冲突——逐个文件查我们有没有改过：

```bash
for f in $(git diff --name-only develop upstream/develop); do
  git diff --name-only develop HEAD -- "$f" | grep -q . && echo "TOUCHED BY FORK: $f" || echo "untouched:      $f"
done
```

实测那次 9 个文件里**只有 `lib/widgets/navigation/drawer/app_drawer.dart` 被我们改过**，
而且改动区域不重叠（上游在 import 块和 `binTile`，我们在 `_AppDrawerState.build` 和 `_buildHeader`），
所以 `--3way` 干净通过、双方改动都保住。

## 冲突解决速查

| 冲突类型 | 处理 |
| --- | --- |
| 整棵树 add/add 冲突（每个文件都冲突） | 说明你用了 `git rebase`/`git merge`。**中止**（`git rebase --abort`），改用上面的 `git diff` + `git apply --3way` |
| 应用 patch 后 `git apply --3way` 报冲突 | 冲突文件会留在 index 里；把两边都想要的改动手工合好，`git add -A`，再从流程第 3 步继续 |
| 应用名 / ARB 文案 | 取上游版本，然后重跑 `scripts/baicha/apply_brand_name.sh` |
| 28 个代码文件 | 保留上游改动，并把我们那个 `if (settings.useMiuixUi) { ... }` 分支重新套上（每个文件的改动都很小、位置固定） |
| `pubspec.lock` / `flavors/*` | 以 `flavors/pubspec_libre.yaml` 为准重新生成，不要手工合并锁文件 |
| `build.gradle.kts` | 保持 `classPackage`/`appId` 分离、ABI 过滤、签名三处；其余取上游 |
| vendor 的 `plugins/flutter_miuix` | 先把新版本覆盖进来，再跑 `scripts/baicha/repatch_flutter_miuix.sh` |

## 本机环境备忘

- Flutter 3.47.7：`D:\0AI\BaiCha\Aves\.flutter-sdk\flutter\bin\flutter.bat`（`FLUTTER_BIN` 指向它）
- JDK 21：`C:\Program Files\Java\jdk-21`；`ANDROID_HOME=C:\Users\ROG\AppData\Local\Android\Sdk`
- git 需要 `core.longpaths=true`（否则依赖 checkout 会被截断）
- release 签名：`D:\0AI\BaiCha\Aves\_keys\aves-baicha.jks`（口令 `aves2026baicha`，别名 `baicha`）→ `android/key.properties`（已加入 `.git/info/exclude`）
- MuMu adb：`C:\Program Files\Netease\MuMu Player 12\shell\adb.exe`，先 `adb connect 127.0.0.1:16416`；应用有时不在主显示上，用 `dumpsys SurfaceFlinger --display-id` 找显示 ID
- 真机：MEIZU 20（`381QJGENRCH8M`），1080x2400 @450dpi（DPR 2.8125），Android 16 / SDK 36，**已 root**（`run-as` 对 release 包不可用，但可直接读 `/data/data/io.github.baicha.aves/shared_prefs/FlutterSharedPreferences.xml`，键名带 `flutter.` 前缀）
  - 读运行时 `MediaQuery`：临时 `print` 插桩 + `adb -s 381QJGENRCH8M logcat -d | Select-String BAICHA_INSETS`。**release 构建里 `Diagnosticable.toString()` 被剥离**，`print(MediaQueryData)` 只会输出 `Instance of 'MediaQueryData'`，必须逐字段打印（`padding.bottom` / `viewPadding.bottom` / `viewInsets.bottom` / `systemGestureInsets.bottom` / `displayCornerRadii`）
  - 屏幕圆角（`bottomDisplayCornerRadius` 的来源）：`adb shell dumpsys display | findstr /i roundedCorners` → 真机四角 `radius=101`（101/2.8125 = 35.9111dp）
  - A/B 对拍：真机上同时装了官方 `deckers.thibault.aves.libre`，用 `uiautomator dump` 取两边底栏 `android.widget.Button` 的 bounds 直接比位置
  - 判断某个 APK 里有没有某段 Dart 代码：从 APK 解出 `lib/arm64-v8a/libapp.so`，按 Latin-1 读成字符串搜符号名（未混淆的构建里类名/方法名都在；`--obfuscate` 的构建搜不到，所以先用已知的应用内类名如 `AvesNavItem` 验证该 APK 是否混淆）

