import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart';

/// 由 aves 的强调色派生完整的 Miuix 调色板。
///
/// 种子色直接取自 aves 当前生效的 [ColorScheme]（用户自定义色，或系统壁纸取色），
/// 因此 Miuix 组件和 aves 原生界面会处在同一个色调族里，切换皮肤时色调不跳变。
MiuixColors avesMiuixColors({required Color accent, required bool dark}) =>
    miuixColorsFromSeed(seed: accent, dark: dark);

/// 给整棵应用界面套上 Miuix 主题。
///
/// 必须放在 `MaterialApp.builder` 里（Flutter 保证该位置在 `Theme` 作用域内），
/// 皮肤关闭时原样返回 [child]，即完全退回 aves 原生外观。
class AvesMiuixTheme extends StatelessWidget {
  const new({super.key, required this.enabled, required this.child});

  /// 是否启用 Miuix 皮肤（来自 aves 设置：显示 → Miuix 界面）。
  final bool enabled;

  final Widget child;

  // Monet 调色板生成有一定开销，而 aves 的根 builder 会在键盘弹出等场景频繁重建，
  // 这里按（强调色, 亮度, 字重偏移）缓存一下。
  static String? _cacheKey;
  static MiuixThemeData? _cache;

  static MiuixThemeData _themeDataFor(ColorScheme scheme, int fontWeightAdjustment) {
    final key = '${scheme.primary.toARGB32()}/${scheme.brightness}/$fontWeightAdjustment';
    if (_cacheKey == key && _cache != null) {
      return _cache!;
    }
    final accent = scheme.primary;
    final data = MiuixThemeData.of(
      scheme.brightness,
      lightColors: avesMiuixColors(accent: accent, dark: false),
      darkColors: avesMiuixColors(accent: accent, dark: true),
      fontWeightAdjustment: fontWeightAdjustment,
    );
    _cacheKey = key;
    _cache = data;
    return data;
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    final theme = Theme.of(context);
    return MiuixTheme(
      // aves 跟随系统的字体加粗设置，这里与 Miuix 的字重偏移对齐
      data: _themeDataFor(theme.colorScheme, MediaQuery.boldTextOf(context) ? 100 : 0),
      child: child,
    );
  }
}
