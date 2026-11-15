import 'package:aves/theme/durations.dart';
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

  @override
  Widget build(BuildContext context) {
    final enabled = children.isNotEmpty == true;
    final miuixTheme = MiuixTheme.of(context);
    Widget titleChild = HighlightTitle(
      title: title,
      locale: locale,
      color: highlightColor,
      enabled: enabled,
      showHighlight: showHighlight,
    );
    titleChild = DefaultTextStyle(
      style: miuixTheme.textStyles.title4.copyWith(
        color: enabled ? miuixTheme.colors.onSurfaceContainer : miuixTheme.colors.disabledOnSecondaryVariant,
        fontWeight: FontWeight.w500,
      ),
      child: titleChild,
    );
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
    final card = ExpansionTileCard(
      // key is expected by test driver
      key: Key('tilecard-$value'),
      value: value,
      expandedNotifier: expandedNotifier,
      title: titleChild,
      expandable: enabled,
      initiallyExpanded: initiallyExpanded,
      borderRadius: const BorderRadius.all(Radius.circular(miuixCardRadius)),
      elevation: 0.0,
      finalPadding: EdgeInsets.zero,
      baseColor: miuixTheme.colors.surfaceContainer,
      expandedTextColor: miuixTheme.colors.onSurfaceContainer,
      duration: animationDuration,
      shadowColor: theme.shadowColor,
      child: _ExpansionTileBodyStorage(
        child: Column(
          crossAxisAlignment: .start,
          children: [
            const ThinDivider(),
            const SizedBox(height: 4),
            if (enabled) ...children,
            const SizedBox(height: miuixCardBottomInset),
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
