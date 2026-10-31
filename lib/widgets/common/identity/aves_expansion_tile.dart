import 'package:aves/theme/durations.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/theme/themes.dart';
import 'package:aves/widgets/common/basic/divider.dart';
import 'package:aves/widgets/common/identity/highlight_title.dart';
import 'package:aves/widgets/settings/language/locales.dart';
import 'package:aves_miuix/aves_miuix.dart';
import 'package:expansion_tile_card/expansion_tile_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class const AvesExpansionTile({
  super.key,
  String? value,
  final Widget? leading,
  required final String title,
  final Widget? trailing,
  required final KnownLocale? locale,
  final Color? highlightColor,
  final ValueNotifier<String?>? expandedNotifier,
  final bool initiallyExpanded = false,
  final bool showHighlight = true,
  required final List<Widget> children,
}) extends StatelessWidget {
  final String value = value ?? title;

  /// Miuix section card spec (see `FORK.md`): 16dp corners (= `MiuixCardDefaults.cornerRadius`),
  /// a flat surface (no elevation, like `MiuixCard`) and an 8dp gap between cards.
  ///
  /// `ExpansionTileCard` has **no margin parameter**, so the gap has to come from an outer
  /// `Padding`; and its `finalPadding` only exists while expanded, which is why the spacing
  /// used to change on expansion — hence `finalPadding: EdgeInsets.zero` plus a small inset
  /// at the end of the expanded child instead.
  static const double miuixCardRadius = 16;
  static const double miuixCardGap = 8;
  static const double miuixCardBottomInset = 4;

  /// Upstream (package) corner radius, kept on the Material path.
  static const BorderRadius _upstreamCardRadius = BorderRadius.all(Radius.circular(8.0));

  @override
  Widget build(BuildContext context) {
    final enabled = children.isNotEmpty == true;
    // baicha fork: Miuix skin → Miuix surface + typography for the section card
    final miuixTheme = settings.useMiuixUi ? MiuixTheme.of(context) : null;
    Widget titleChild = HighlightTitle(
      title: title,
      locale: locale,
      color: highlightColor,
      enabled: enabled,
      showHighlight: showHighlight,
    );
    if (miuixTheme != null) {
      titleChild = DefaultTextStyle(
        style: miuixTheme.textStyles.title4.copyWith(
          color: enabled ? miuixTheme.colors.onSurfaceContainer : miuixTheme.colors.disabledOnSecondaryVariant,
          fontWeight: FontWeight.w500,
        ),
        child: titleChild,
      );
    }
    final _leading = leading;
    final _trailing = trailing;
    if (_leading != null || _trailing != null) {
      titleChild = Row(
        children: [
          if (_leading != null) ...[
            _leading,
            const SizedBox(width: 8),
          ],
          Expanded(child: titleChild),
          if (_trailing != null) ...[
            const SizedBox(width: 8),
            _trailing,
          ],
        ],
      );
    }

    final animationDuration = context.select<DurationsData, Duration>((v) => v.expansionTileAnimation);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final card = ExpansionTileCard(
      // key is expected by test driver
      key: Key('tilecard-$value'),
      value: value,
      expandedNotifier: expandedNotifier,
      title: titleChild,
      expandable: enabled,
      initiallyExpanded: initiallyExpanded,
      // baicha fork: Miuix-only — rounder, flat cards with a constant gap; the Material
      // path keeps the package defaults explicitly so that it stays pixel identical.
      borderRadius: miuixTheme != null ? const BorderRadius.all(Radius.circular(miuixCardRadius)) : _upstreamCardRadius,
      elevation: miuixTheme != null ? 0.0 : 2.0,
      finalPadding: miuixTheme != null ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 6.0),
      baseColor: miuixTheme?.colors.surfaceContainer ?? Themes.firstLayerColor(context),
      expandedTextColor: miuixTheme?.colors.onSurfaceContainer ?? colorScheme.onSurface,
      duration: animationDuration,
      shadowColor: theme.shadowColor,
      child: _ExpansionTileBodyStorage(
        child: Column(
          crossAxisAlignment: .start,
          children: [
            const ThinDivider(),
            const SizedBox(height: 4),
            if (enabled) ...children,
            // Miuix: upstream's `finalPadding` also kept the last row off the card's rounded
            // bottom edge, but it changed the outer spacing on expansion; do it inside instead
            if (miuixTheme != null) const SizedBox(height: miuixCardBottomInset),
          ],
        ),
      ),
    );
    // `ExpansionTileCard` persists whether it is expanded through `PageStorage`.
    // That lookup only considers `PageStorageKey` ancestors, not the plain key above
    // (which the test driver relies on). Without this wrapper, scrolling the expanded
    // section out of a `ListView` disposes its state; the shared expanded notifier still
    // names this section, but the recreated card starts its height animation collapsed,
    // making the list suddenly shrink and the viewport jump.
    final storedCard = KeyedSubtree(
      key: PageStorageKey<String>('tilecard-storage-$value'),
      child: card,
    );
    // the gap lives outside the card, so expansion never changes the spacing
    if (miuixTheme == null) return storedCard;
    return Padding(
      padding: const EdgeInsets.only(bottom: miuixCardGap),
      child: storedCard,
    );
  }
}

/// Isolates scroll state inside an expanded card from the expansion flag stored by
/// `ExpansionTileCard`. Without a separate bucket, a nested `SelectableText` reads
/// that flag as its scroll offset.
class _ExpansionTileBodyStorage extends StatefulWidget {
  const new({required this.child});

  final Widget child;

  @override
  State<_ExpansionTileBodyStorage> createState() => _ExpansionTileBodyStorageState();
}

class _ExpansionTileBodyStorageState extends State<_ExpansionTileBodyStorage> {
  final PageStorageBucket _bucket = PageStorageBucket();

  @override
  Widget build(BuildContext context) => PageStorage(
    bucket: _bucket,
    child: widget.child,
  );
}
