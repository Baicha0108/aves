# Aves Single-UI Migration Checklist

目标：以最新 `upstream/develop` 为干净基线，把 Aves 原版 UI 直接改造成当前 Miuix 视觉，只维护一套界面和一套导航行为。

## 1. 基线与安全

- [x] 从 `upstream/develop` 创建独立的 `single-ui` 分支。
- [x] 保留原 `develop` 作为完整回退参考。
- [x] 不把旧 `useMiuixUi` 条件分支整体合并回来。

## 2. 单套 Miuix 设计系统

- [x] 引入本地 `aves_miuix` 和 `flutter_miuix`。
- [x] 根应用始终挂载 Miuix 主题，不依赖运行时开关。
- [x] 设置中不再显示 Miuix UI 开关。
- [x] 删除 `useMiuixUi` 设置读取和所有双 UI 分支。

## 3. 原版 UI 直接改造

- [x] 顶栏和浮动栏使用唯一 Miuix 风格。
- [x] 底部导航使用唯一 Miuix 悬浮胶囊及左/中/右位置设置。
- [x] 抽屉直接使用 Miuix 卡片分组。
- [x] 设置页直接使用 Miuix 行、卡片和弹层。
- [x] 图片信息页直接使用 Miuix 分区卡片。
- [x] 对话框、菜单、底部弹层、Snackbar 和筛选 Chip 使用唯一 Miuix 风格。

## 4. 导航与页面状态

- [x] 分页壳作为唯一导航实现。
- [x] 页面路由身份、滚动控制器和标签状态互不串扰。
- [x] 抽屉入口不会摧毁分页壳。
- [x] 底栏配置重排、删空和重新添加后行为正确。

## 5. 产品与构建定制

- [x] 保留 `io.github.baicha.aves`、`Aves Miuix` 和 arm64-v8a 单包。
- [x] Libre Release 构建和标签发布流程保持可用。
- [x] Android TV 布局禁用。
- [x] 自动质量检查保持手动运行。

## 6. 既有 Bug 修复

- [x] 设置页分区展开后的滚动瞬移修复。
- [x] 图片元数据分区展开后的灰白/超长内容修复。
- [x] 长按多选和标签页滚动隔离修复。
- [x] 抽屉滚动不再带动底栏隐藏。

## 7. 测试与清理

- [x] 删除 Material fallback 和双皮肤一致性测试。
- [x] 保留单套 Miuix 视觉、导航、布局和持久化回归测试。
- [x] 全项目静态分析无问题。
- [x] 主项目测试全部通过。
- [x] vendored `flutter_miuix` 测试全部通过。

## 8. 交付

- [ ] 构建 Libre Release arm64 APK。
- [ ] 核验包名、版本、ABI 和 V2 签名。
- [ ] 按约定命名并归档 APK。
- [ ] 更新 `fork.md` 完成记录。
- [ ] 本地提交，不主动推送 GitHub。
