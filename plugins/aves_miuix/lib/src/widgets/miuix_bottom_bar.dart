import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart';

/// 一个底栏条目。
@immutable
class AvesMiuixBottomBarItem {
  const new({
    required this.icon,
    required this.label,
  });

  final Widget icon;
  final String label;
}

/// KSU 风格的悬浮底栏：胶囊容器 + 图标 + 11sp 文字 + 会滑动的选中指示器。
///
/// 规格取自 KernelSU 的 `FloatingBottomBar`（其本身改自 miuix 的 iOS 液态玻璃导航栏示例）：
/// - 容器高 64dp、四周 4dp 内边距、胶囊形（圆角 50）、投影 blur 10 / 黑 20%（深色）
/// - 每项最小宽 76dp，内容为图标 + 11sp 单行文字
/// - 选中项有强调色指示器（`primary` 15% 透明），位置随选中项滑动
/// - 容器宽度按内容收缩（不是通栏），水平位置可配置为靠左、居中或靠右
class AvesMiuixBottomBar extends StatelessWidget {
  const new({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    this.alignment = Alignment.center,
  });

  final List<AvesMiuixBottomBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final Alignment alignment;

  static const double barHeight = 64;
  static const double barPadding = 4;
  static const double indicatorHeight = 56;
  static const double minItemWidth = 76;
  static const double iconSize = 24;
  static const double labelFontSize = 11;
  static const double edgeInset = 12;
  static const Duration indicatorDuration = Duration(milliseconds: 260);
  static const surfaceKey = Key('miuix-bottom-bar-surface');

  @override
  Widget build(BuildContext context) {
    final theme = MiuixTheme.of(context);
    final colors = theme.colors;
    final textScaler = MediaQuery.textScalerOf(context);
    const labelStyle = TextStyle(
      fontSize: labelFontSize,
      height: 14 / labelFontSize,
      fontWeight: FontWeight.w500,
    );

    // 条目等宽：以最长标签为准，但不小于 minItemWidth，也不超过可平分到的宽度
    final widestLabel = items.fold<double>(0, (maxWidth, item) {
      final painter = TextPainter(
        text: TextSpan(text: item.label, style: labelStyle),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      return math.max(maxWidth, painter.width);
    });
    final contentWidth = math.max(minItemWidth, widestLabel + 24);
    // KSU 用 surfaceContainer；我们这套 Miuix 调色板里它与页面几乎同色，改用更亮一档保证轮廓
    final containerColor = colors.surfaceContainerHigh;

    final edgePadding = switch (alignment) {
      Alignment.centerLeft => const EdgeInsets.only(left: edgeInset),
      Alignment.centerRight => const EdgeInsets.only(right: edgeInset),
      _ => EdgeInsets.zero,
    };

    return Padding(
      padding: edgePadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = items.length;
          if (count == 0) return const SizedBox.shrink();
          final maxContentWidth = constraints.maxWidth - barPadding * 2;
          final itemWidth = math.min(contentWidth, maxContentWidth / count);
          final indicatorWidth = itemWidth - 0; // 指示器与条目同宽

          return Align(
            alignment: alignment,
            child: Container(
              key: surfaceKey,
              height: barHeight,
              padding: const EdgeInsets.all(barPadding),
              decoration: ShapeDecoration(
                color: containerColor,
                shape: const StadiumBorder(),
                shadows: const [BoxShadow(color: Color(0x33000000), blurRadius: 10)],
              ),
              child: SizedBox(
                width: itemWidth * count,
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: indicatorDuration,
                      curve: Curves.easeOutCubic,
                      left: currentIndex.clamp(0, count - 1) * itemWidth,
                      top: 0,
                      width: indicatorWidth,
                      height: indicatorHeight,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: colors.primary.withValues(alpha: .15),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var index = 0; index < count; index++)
                          SizedBox(
                            width: itemWidth,
                            child: _MiuixBottomBarTab(
                              item: items[index],
                              labelStyle: labelStyle,
                              selected: index == currentIndex,
                              onPressed: () => onSelected(index),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiuixBottomBarTab extends StatefulWidget {
  const new({
    required this.item,
    required this.labelStyle,
    required this.selected,
    required this.onPressed,
  });

  final AvesMiuixBottomBarItem item;
  final TextStyle labelStyle;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_MiuixBottomBarTab> createState() => _MiuixBottomBarTabState();
}

class _MiuixBottomBarTabState extends State<_MiuixBottomBarTab> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MiuixTheme.of(context).colors;
    final tint = widget.selected ? colors.primary : colors.onSurface;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTheme(
              data: IconThemeData(
                color: tint,
                size: AvesMiuixBottomBar.iconSize,
              ),
              child: SizedBox.square(
                dimension: AvesMiuixBottomBar.iconSize,
                child: Center(child: widget.item.icon),
              ),
            ),
            const SizedBox(height: 1),
            DefaultTextStyle(
              style: widget.labelStyle.copyWith(color: tint),
              child: Text(
                widget.item.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
