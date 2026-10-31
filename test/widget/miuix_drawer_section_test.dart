import 'package:aves_miuix/aves_miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Width of the Material `Drawer` at this device's density (855px / 2.8125 device pixel ratio).
const _drawerWidth = 304.0;

Future<void> _pumpSection(WidgetTester tester, Widget section, {bool dark = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: dark ? .dark : .light),
      builder: (context, child) => AvesMiuixTheme(enabled: true, child: child!),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: _drawerWidth, child: section),
        ),
      ),
    ),
  );
}

MiuixColors _colorsOf(WidgetTester tester, Finder finder) => MiuixTheme.of(tester.element(finder)).colors;

void main() {
  group('AvesMiuixDrawerSection', () {
    testWidgets('the first card keeps the same gap below the header as between cards', (tester) async {
      const ltr = TextDirection.ltr;
      // the header is not a card, so the leading section has to add the top gap itself,
      // and it must match the gap the other cards get from their bottom margin
      expect(
        AvesMiuixDrawerSection.leadingMargin.resolve(ltr).top,
        AvesMiuixDrawerSection.defaultMargin.resolve(ltr).bottom,
      );
      expect(AvesMiuixDrawerSection.defaultMargin.resolve(ltr).top, 0);

      await _pumpSection(
        tester,
        AvesMiuixDrawerSection(
          margin: AvesMiuixDrawerSection.leadingMargin,
          children: [ListTile(title: const Text('all'), onTap: () {})],
        ),
      );
      expect(tester.getTopLeft(find.byType(MiuixCard)).dy, AvesMiuixDrawerSection.leadingMargin.resolve(ltr).top);
    });

    testWidgets('one rounded card per section, inset from the drawer edges', (tester) async {
      await _pumpSection(
        tester,
        AvesMiuixDrawerSection(
          children: [
            ListTile(title: const Text('all'), onTap: () {}),
            ListTile(title: const Text('recent'), onTap: () {}),
          ],
        ),
      );

      expect(find.byType(MiuixCard), findsOneWidget);
      final card = tester.widget<MiuixCard>(find.byType(MiuixCard));
      expect(card.cornerRadius, AvesMiuixDrawerSection.defaultCornerRadius);

      // the card is inset 8dp on both sides
      expect(tester.getSize(find.byType(MiuixCard)).width, _drawerWidth - 16);
      // every tile is inset 4dp more, so the selection pill keeps a small gap from the card edge
      expect(tester.getSize(find.byType(ListTile).first).width, _drawerWidth - 16 - 8);

      // the card color is the Miuix surface, i.e. set apart from the drawer background
      final colors = _colorsOf(tester, find.byType(MiuixCard));
      final decoration = tester
          .widgetList<DecoratedBox>(find.descendant(of: find.byType(MiuixCard), matching: find.byType(DecoratedBox)))
          .map((w) => w.decoration)
          .whereType<ShapeDecoration>()
          .firstWhere((d) => d.shape is MiuixSquircleBorder);
      expect(colors.surfaceContainer, isNot(colors.background));
      expect(decoration.color, colors.surfaceContainer);

      // the tiles need their own (transparent) Material inside the card, otherwise the
      // card's background would hide the selection highlight painted on the drawer Material
      final nearestMaterial = tester
          .widgetList<Material>(find.ancestor(of: find.byType(ListTile).first, matching: find.byType(Material)))
          .first;
      expect(nearestMaterial.type, MaterialType.transparency);
    });

    testWidgets('card stays distinguishable from the background in dark mode', (tester) async {
      await _pumpSection(
        tester,
        AvesMiuixDrawerSection(children: [ListTile(title: const Text('all'), onTap: () {})]),
        dark: true,
      );

      final colors = _colorsOf(tester, find.byType(MiuixCard));
      expect(colors.surfaceContainer, isNot(colors.background));
    });

    testWidgets('an empty section renders nothing', (tester) async {
      await _pumpSection(tester, const AvesMiuixDrawerSection(children: []));

      expect(find.byType(MiuixCard), findsNothing);
    });
  });

  group('drawer selection pill', () {
    // the drawer's own `ListTileTheme.merge` values
    Widget themedTile({required bool selected}) => Builder(
      builder: (context) {
        final colors = MiuixTheme.of(context).colors;
        return ListTileTheme.merge(
          shape: AvesMiuixDrawerSection.selectionShape,
          contentPadding: AvesMiuixDrawerSection.itemContentPadding,
          selectedTileColor: colors.secondaryContainer,
          child: Material(
            child: ListTile(
              leading: const Icon(Icons.image),
              title: const Text('all'),
              selected: selected,
              onTap: () {},
            ),
          ),
        );
      },
    );

    testWidgets('the selected tile is a rounded pill, not a full-width rectangle', (tester) async {
      await _pumpSection(tester, themedTile(selected: true));

      expect(
        AvesMiuixDrawerSection.selectionShape,
        const MiuixSquircleBorder(cornerRadius: AvesMiuixDrawerSection.selectionCornerRadius),
      );
      expect(AvesMiuixDrawerSection.selectionCornerRadius, lessThan(AvesMiuixDrawerSection.defaultCornerRadius));

      final colors = _colorsOf(tester, find.byType(ListTile));
      final ink = tester.widget<Ink>(find.descendant(of: find.byType(ListTile), matching: find.byType(Ink)).first);
      final decoration = ink.decoration! as ShapeDecoration;
      expect(decoration.shape, AvesMiuixDrawerSection.selectionShape);
      expect(decoration.color, colors.secondaryContainer);
    });

    testWidgets('the tile content is inset by the section padding', (tester) async {
      await _pumpSection(tester, themedTile(selected: false));

      final safeArea = tester.widget<SafeArea>(
        find.descendant(of: find.byType(ListTile), matching: find.byType(SafeArea)).first,
      );
      final minimum = safeArea.minimum;
      final expected = AvesMiuixDrawerSection.itemContentPadding.resolve(TextDirection.ltr);
      expect(minimum.left, expected.left);
      expect(minimum.left, 12);
      // upstream's default content padding, i.e. what the Material skin keeps
      expect(minimum.left, lessThan(16));
    });
  });
}
