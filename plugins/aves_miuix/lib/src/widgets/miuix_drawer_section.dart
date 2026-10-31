// Aves 的 Miuix 抽屉「大块」容器。
//
// 上游（Material）抽屉是一条通栏列表 + `Divider` 分组的扁平结构；Miuix 皮肤把它
// 换成 KSU / HyperOS 那种「卡片分组」：相邻的导航项收进一张圆角卡片里，卡片颜色
// 取自 [MiuixCardDefaults]（`surfaceContainer`），与抽屉背景（`background`）形成层次。
// 卡片高度完全由内容决定 —— 所以在设置里增删抽屉选项后，卡片会跟着变高变矮。
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart';

/// 抽屉里的一个「大块」：内缩的 Miuix 卡片 + 卡片内衬。
///
/// 每个导航项（tile）外面会再包一层 [itemPadding]，让选中态高亮（由抽屉的
/// `ListTileTheme` 配上 [selectionShape] 画成圆角）与卡片边缘留出很小的间距。
class AvesMiuixDrawerSection extends StatelessWidget {
  const new({
    super.key,
    required this.children,
    this.cornerRadius = defaultCornerRadius,
    this.margin = defaultMargin,
    this.insidePadding = const EdgeInsets.symmetric(vertical: 4),
    this.itemPadding = defaultItemPadding,
  });

  /// 这一块里的导航项，按显示顺序排列。
  final List<Widget> children;

  /// 卡片圆角，与 Miuix 卡片默认值一致（squircle）。
  final double cornerRadius;

  /// 卡片相对抽屉左右边缘的外边距，以及卡片之间的间距（由 [margin] 的 bottom 提供）。
  final EdgeInsetsGeometry margin;

  /// 卡片自己的上下内衬：让第一项/最后一项的选中态高亮不贴到卡片上下边缘。
  final EdgeInsetsGeometry insidePadding;

  /// 每一项相对卡片左右边缘的内缩量。
  final EdgeInsetsGeometry itemPadding;

  /// 卡片圆角，16dp = [MiuixCardDefaults.cornerRadius]。
  static const double defaultCornerRadius = 16;

  /// 卡片外边距：左右 8dp（离抽屉边缘）＋ 下方 8dp（与下一块的间距）。
  static const EdgeInsetsGeometry defaultMargin = EdgeInsets.only(left: 8, right: 8, bottom: 8);

  /// 紧跟在头部下面的那一块：头部自己不是卡片（它是一条通栏的强调色区域），
  /// 所以上方也要补上与卡片间距相同的 8dp，否则两块会贴在一起。
  static const EdgeInsetsGeometry leadingMargin = EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 8);

  /// 选中小块的圆角：比卡片小一个内缩量，与卡片保持同心。
  static const double selectionCornerRadius = defaultCornerRadius - 4;

  /// 每一项相对卡片边缘的内缩量（4dp）。
  static const EdgeInsetsGeometry defaultItemPadding = EdgeInsets.symmetric(horizontal: 4);

  /// 导航项内容相对小块边缘的内缩量（Miuix 列表项的常规留白）。
  static const EdgeInsetsGeometry itemContentPadding = EdgeInsets.symmetric(horizontal: 12);

  /// 供抽屉的 `ListTileTheme.merge` 使用的选中态形状（圆角小块）。
  static const ShapeBorder selectionShape = MiuixSquircleBorder(cornerRadius: selectionCornerRadius);

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: margin,
      child: MiuixCard(
        cornerRadius: cornerRadius,
        insideMargin: insidePadding,
        // 卡片自己的底色画在 `DecoratedBox` 上，而 `ListTile` 的选中态/水波纹是画在
        // 最近的 `Material` 上的 —— 没有这层透明 `Material`，高亮会被卡片底色盖住。
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: children.map((child) => Padding(padding: itemPadding, child: child)).toList(),
          ),
        ),
      ),
    );
  }
}
