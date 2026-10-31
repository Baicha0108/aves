import 'package:aves/model/settings/settings.dart';
import 'package:aves/theme/colors.dart';
import 'package:aves/theme/durations.dart';
import 'package:aves/widgets/common/identity/aves_expansion_tile.dart';
import 'package:aves/widgets/settings/language/locales.dart';
import 'package:aves/widgets/viewer/info/common.dart';
import 'package:aves_miuix/aves_miuix.dart';
import 'package:expansion_tile_card/expansion_tile_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../common.dart';

/// 设置页 / 图片信息页的分区卡片（`AvesExpansionTile`）规格回归测试。
///
/// 原则（见 FORK.md）：Miuix 侧 = 16dp 圆角、卡片之间恒定 8dp、扁平无抬高；
/// Material 侧必须保持包/上游的默认值（8dp / 2.0 / 展开时上下 6dp）且不额外加间距。
///
/// 历史问题：`ExpansionTileCard` 没有 margin 参数，卡片之间 0 间距（贴在一起）；
/// 它的 `finalPadding` 又只在展开时出现，所以展开才会「多出」间距。
void main() {
  setUpAll(() async {
    await setUpAllServices();
  });

  tearDownAll(() async {
    await tearDownAllServices();
  });

  late bool originalSetting;

  setUp(() async {
    await setUpServices();
    originalSetting = settings.useMiuixUi;
  });

  tearDown(() {
    settings.useMiuixUi = originalSetting;
  });

  Future<void> pumpTwoTiles(WidgetTester tester, {required bool miuix}) async {
    settings.useMiuixUi = miuix;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        builder: (context, child) => AvesMiuixTheme(enabled: miuix, child: child!),
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<Settings>.value(value: settings),
            Provider<DurationsData>.value(value: DurationsData()),
          ],
          child: AvesColorsProvider(
            child: Scaffold(
              body: ListView(
                children: const [
                  AvesExpansionTile(title: 'section A', locale: KnownLocale.english, children: [Text('a')]),
                  AvesExpansionTile(title: 'section B', locale: KnownLocale.english, children: [Text('b')]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<ExpansionTileCard> cardsOf(WidgetTester tester) => tester.widgetList<ExpansionTileCard>(find.byType(ExpansionTileCard)).toList();

  double gapBetweenCards(WidgetTester tester) => tester.getTopLeft(find.byType(ExpansionTileCard).at(1)).dy - tester.getBottomLeft(find.byType(ExpansionTileCard).at(0)).dy;

  testWidgets('Miuix: 16dp corners, flat card, constant 8dp gap', (tester) async {
    await pumpTwoTiles(tester, miuix: true);

    final cards = cardsOf(tester);
    expect(cards, hasLength(2));
    for (final card in cards) {
      expect(card.borderRadius, const BorderRadius.all(Radius.circular(AvesExpansionTile.miuixCardRadius)));
      expect(card.borderRadius, const BorderRadius.all(Radius.circular(16)));
      expect(card.elevation, 0);
      expect(card.finalPadding, EdgeInsets.zero);
    }
    expect(gapBetweenCards(tester), AvesExpansionTile.miuixCardGap);

    // expanding must not change the outer spacing (the old `finalPadding` did)
    await tester.tap(find.byType(ExpansionTileCard).first);
    await tester.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);
    expect(gapBetweenCards(tester), AvesExpansionTile.miuixCardGap);
  });

  testWidgets('Material: package/upstream values, no extra gap', (tester) async {
    await pumpTwoTiles(tester, miuix: false);

    final cards = cardsOf(tester);
    expect(cards, hasLength(2));
    for (final card in cards) {
      expect(card.borderRadius, const BorderRadius.all(Radius.circular(8.0)));
      expect(card.elevation, 2.0);
      expect(card.finalPadding, const EdgeInsets.symmetric(vertical: 6.0));
    }
    expect(gapBetweenCards(tester), 0);
  });

  testWidgets('Miuix: expansion survives the card being scrolled out of the viewport', (tester) async {
    settings.useMiuixUi = true;
    final expandedNotifier = ValueNotifier<String?>(null);
    addTearDown(expandedNotifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        builder: (context, child) => AvesMiuixTheme(enabled: true, child: child!),
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<Settings>.value(value: settings),
            Provider<DurationsData>.value(value: DurationsData()),
          ],
          child: AvesColorsProvider(
            child: Scaffold(
              body: ListView(
                children: [
                  AvesExpansionTile(
                    value: 'display',
                    title: 'display',
                    locale: KnownLocale.english,
                    expandedNotifier: expandedNotifier,
                    children: const [SizedBox(height: 240, child: Text('display child'))],
                  ),
                  const SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ExpansionTileCard));
    await tester.pumpAndSettle();
    final expandedHeight = tester.getSize(find.byType(ExpansionTileCard)).height;
    expect(expandedHeight, greaterThan(250));

    // Scroll far enough for the ListView to dispose the expansion tile,
    // then come back to the top. The shared notifier still says "display",
    // so the recreated card must render expanded rather than collapsed.
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 1600));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(ExpansionTileCard)).height, closeTo(expandedHeight, 1));
  });

  testWidgets('Miuix: metadata body does not inherit the expansion flag as scroll offset', (tester) async {
    settings.useMiuixUi = true;
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        builder: (context, child) => AvesMiuixTheme(enabled: true, child: child!),
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<Settings>.value(value: settings),
            Provider<DurationsData>.value(value: DurationsData()),
          ],
          child: AvesColorsProvider(
            child: Scaffold(
              body: AvesExpansionTile(
                title: 'Huffman',
                locale: KnownLocale.english,
                children: const [
                  InfoRowGroup(
                    info: {
                      'Code Length': '8',
                      'Value': 'example',
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ExpansionTileCard));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(SelectableText)).height, lessThan(500));
  });
}
