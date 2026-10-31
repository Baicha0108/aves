import 'package:aves/model/settings/settings.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/providers/shell_tab_provider.dart';
import 'package:aves/widgets/common/tile_extent_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../common.dart';

/// `ShellTabScope` 回归测试。
///
/// 历史 bug：在「媒体集」里把网格缩放到 4 列后，「相册」页的小合集也跟着变 4 列。
/// 原因：`MainShellPage` 把所有标签放进同一个 route 的 `PageView`，`ModalRoute` 无法
/// 区分页面，于是用 `ShellTabScope` 暴露 route name —— 但它最初只装在 scaffold 外层，
/// 携带的是**当前激活标签**的 route。相册页被 `PageView` 懒构建时会读到「媒体集」的
/// `/collection`，于是把 `tile_extent_/collection` 当成自己的设置读（且只读一次并缓存，
/// 永不恢复），缩放媒体集就直接改掉相册的列数。
///
/// 修复：shell 在**两层**安装 scope——
/// * scaffold 外层 → 「当前激活标签」，给底栏 / 抽屉 / TV 导轨用；
/// * 每个页面槽位内层 → 「该页自己的 route」，给页内按 route 存取的设置用。
void main() {
  setUpAll(() async {
    await setUpAllServices();
  });

  tearDownAll(() async {
    await tearDownAllServices();
  });

  setUp(() async {
    await setUpServices();
  });

  const collectionRoute = '/collection';
  const albumsRoute = '/albums';

  Widget probe(void Function(String?) onResolve) => Builder(
        builder: (context) {
          onResolve(context.currentRouteName);
          return const SizedBox();
        },
      );

  testWidgets('no tab scope: falls back to the route name', (tester) async {
    String? resolved;
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => MaterialPageRoute(
          // the shell overrides this name when a page is hosted
          settings: const RouteSettings(name: albumsRoute),
          builder: (context) => probe((v) => resolved = v),
        ),
      ),
    );
    expect(resolved, albumsRoute);
  });

  testWidgets('shell scope exposes the active tab', (tester) async {
    String? resolved;
    await tester.pumpWidget(
      MaterialApp(
        home: ShellTabScope(
          routeName: collectionRoute,
          child: probe((v) => resolved = v),
        ),
      ),
    );
    expect(resolved, collectionRoute);
  });

  testWidgets('per-page scope wins over the shell-wide one', (tester) async {
    // the shell shows the collection tab while the albums page is being built
    String? barResolved;
    String? pageResolved;
    await tester.pumpWidget(
      MaterialApp(
        home: ShellTabScope(
          routeName: collectionRoute,
          child: Column(
            children: [
              // what the bottom bar / drawer see
              probe((v) => barResolved = v),
              // what a hosted page sees
              ShellTabScope(
                routeName: albumsRoute,
                child: probe((v) => pageResolved = v),
              ),
            ],
          ),
        ),
      ),
    );
    expect(barResolved, collectionRoute);
    expect(
      pageResolved,
      albumsRoute,
      reason: '被 host 的页面必须看到自己的 route，否则会读写别的标签的按 route 设置',
    );
  });

  testWidgets('sibling pages keep their own routes', (tester) async {
    final resolved = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ShellTabScope(
          routeName: collectionRoute,
          child: Column(
            children: [
              for (final route in [collectionRoute, albumsRoute])
                ShellTabScope(routeName: route, child: probe(resolved.add)),
            ],
          ),
        ),
      ),
    );
    expect(resolved, [collectionRoute, albumsRoute]);
  });

  testWidgets('tile extent controller is keyed by the page own route', (tester) async {
    settings.setTileExtent(collectionRoute, 100);
    settings.setTileExtent(albumsRoute, 126);

    TileExtentController? controller;
    await tester.pumpWidget(
      MaterialApp(
        // active tab is the collection, but this slot hosts the albums page
        home: ShellTabScope(
          routeName: collectionRoute,
          child: ShellTabScope(
            routeName: albumsRoute,
            child: Builder(
              builder: (context) {
                // same expression as `FilterGridPage` when no explicit key is passed
                controller ??= TileExtentController(
                  settingsRouteKey: context.currentRouteName!,
                  columnCountDefault: 3,
                  extentMin: 60,
                  extentMax: 300,
                  spacing: 8,
                  horizontalPadding: 2,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    addTearDown(() => controller!.dispose());
    expect(controller!.settingsRouteKey, albumsRoute);
    expect(
      controller!.userPreferredExtent,
      126,
      reason: '相册页必须读自己的 tile_extent_/albums，而不是媒体集的 tile_extent_/collection',
    );
  });
}
