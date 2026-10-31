// Aves 的 Miuix（HyperOS / MIUI）皮肤层。
//
// 这个包只负责把 Miuix 设计系统接进 aves：
// 1. 用 aves 自己的强调色（含壁纸取色）派生 Miuix 调色板，保证两套主题同色系；
// 2. 提供皮肤开关（P0 为全局静态开关，P1 接入 aves 设置体系）；
// 3. 后续在这里放 aves 专属的 Miuix 组件适配与补齐组件（Chip / ExpansionTile / Drawer）。

// 让 aves 只依赖 `aves_miuix`：以后即使换掉底层移植库，应用侧代码不用动。
export 'package:flutter_miuix/miuix.dart';

export 'src/miuix_theme.dart';
export 'src/widgets/miuix_bottom_bar.dart';
export 'src/widgets/miuix_drawer_section.dart';
