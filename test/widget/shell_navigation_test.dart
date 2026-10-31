import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/filters/favourite.dart';
import 'package:aves/widgets/collection/collection_page.dart';
import 'package:aves/widgets/common/behaviour/app_route_observer.dart';
import 'package:aves/widgets/common/providers/shell_tab_provider.dart';
import 'package:aves/widgets/explorer/explorer_page.dart';
import 'package:aves/widgets/filter_grids/albums_page.dart';
import 'package:aves/widgets/filter_grids/tags_page.dart';
import 'package:aves/widgets/home/home_page.dart';
import 'package:aves/widgets/common/search/page.dart';
import 'package:aves/widgets/navigation/drawer/collection_nav_tile.dart';
import 'package:aves/widgets/navigation/drawer/page_nav_tile.dart';
import 'package:aves/widgets/navigation/main_shell_lifecycle.dart';
import 'package:aves/widgets/navigation/main_shell_page.dart';
import 'package:aves/widgets/navigation/nav_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Records what the shell was asked to do, and hosts [hosted] destinations.
class _FakeShell extends ShellNavigation {
  new({required Set<String> hosted})
    : super(
        routes: hosted.toList(),
        switchTo: (route, filters) => hosted.contains(route),
      );

  final List<String> calls = [];

  @override
  bool goTo(String route, {Set<CollectionFilter>? filters}) {
    calls.add(route);
    return super.goTo(route, filters: filters);
  }
}

/// Pushes [tile] on its own route, so that its `Navigator.pop()` has something to pop —
/// exactly like the drawer, which registers a local history entry when opened.
Future<void> _pushTile(WidgetTester tester, Widget tile) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('shell')),
    ),
  );
  navigatorKey.currentState!.push(
    MaterialPageRoute(
      builder: (_) => Scaffold(body: Material(child: tile)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('app route observer exposes the current page route', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    addTearDown(() => appRouteObserver.currentRoute.value = null);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [appRouteObserver],
        home: const Scaffold(body: Text('base')),
      ),
    );
    expect(appRouteObserver.currentRoute.value?.settings.name == '/detail', isFalse);

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/detail'),
        builder: (_) => const Scaffold(body: Text('detail')),
      ),
    );
    await tester.pumpAndSettle();
    expect(appRouteObserver.currentRoute.value?.settings.name, '/detail');

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(appRouteObserver.currentRoute.value?.settings.name == '/detail', isFalse);
  });

  group('ShellNavigation', () {
    test('no shell is registered by default', () {
      expect(ShellNavigation.current, isNull);
    });

    test('activating publishes the shell, deactivating clears it', () {
      final shell = _FakeShell(hosted: {CollectionPage.routeName});
      addTearDown(shell.deactivate);

      shell.activate();
      expect(ShellNavigation.current, same(shell));

      shell.deactivate();
      expect(ShellNavigation.current, isNull);
    });

    test('deactivating a stale shell does not clear the active one', () {
      final stale = _FakeShell(hosted: const {});
      final active = _FakeShell(hosted: const {});
      addTearDown(active.deactivate);
      addTearDown(stale.deactivate);

      stale.activate();
      active.activate();
      stale.deactivate();

      expect(ShellNavigation.current, same(active));
    });

    test('hosts() only reports the destinations of the bar', () {
      final shell = _FakeShell(hosted: {CollectionPage.routeName, AlbumListPage.routeName});

      expect(shell.hosts(CollectionPage.routeName), isTrue);
      expect(shell.hosts(AlbumListPage.routeName), isTrue);
      expect(shell.hosts(TagListPage.routeName), isFalse);
    });

    test('goTo() reports whether the shell hosts the destination', () {
      final shell = _FakeShell(hosted: {CollectionPage.routeName});

      expect(shell.goTo(CollectionPage.routeName), isTrue);
      expect(shell.goTo(TagListPage.routeName), isFalse);
      expect(shell.calls, [CollectionPage.routeName, TagListPage.routeName]);
    });

    test('openOver() delegates without changing the hosted tabs', () {
      var opened = false;
      final shell = ShellNavigation(
        routes: const [CollectionPage.routeName],
        switchTo: (_, _) => false,
        openOverShell: (route, filters, path, currentCollection) {
          opened = true;
          return true;
        },
      );

      expect(shell.openOver(SearchPage.routeName), isTrue);
      expect(opened, isTrue);
      expect(shell.hosts(SearchPage.routeName), isFalse);
    });
  });

  group('MainShellPage navigation config', () {
    const allMedia = AvesNavItem(route: CollectionPage.routeName);
    final favourites = AvesNavItem(route: CollectionPage.routeName, filters: {FavouriteFilter.instance});
    const albums = AvesNavItem(route: AlbumListPage.routeName);

    test('home destination matches collection filters, not only the route', () {
      final items = [allMedia, favourites, albums];
      expect(MainShellPage.homeIndexFor(items, favourites), 1);
      expect(MainShellPage.homeIndexFor(items, const AvesNavItem(route: CollectionPage.routeName, filters: {})), 0);
      expect(MainShellPage.homeIndexFor(items, const AvesNavItem(route: TagListPage.routeName)), -1);
      expect(
        MainShellPage.homeIndexFor(
          const [
            AvesNavItem(route: ExplorerPage.routeName),
            AvesNavItem(route: ExplorerPage.routeName, path: '/custom'),
          ],
          const AvesNavItem(route: ExplorerPage.routeName, path: '/custom'),
        ),
        1,
      );
    });

    test('config changes preserve the selected item across reordering', () {
      expect(
        MainShellPage.preferredIndex([albums, allMedia, favourites], previous: allMedia, home: allMedia),
        1,
      );
      expect(
        MainShellPage.preferredIndex([favourites, albums], previous: allMedia, home: favourites),
        0,
      );
    });

    test('an empty navigation config can restore the exact standalone page', () {
      final items = [allMedia, favourites, albums];
      expect(MainShellPage.canHost(const [], allMedia), isFalse);

      MainShellLifecycle.updatePage(
        route: CollectionPage.routeName,
        filters: {FavouriteFilter.instance},
      );
      addTearDown(MainShellLifecycle.clearPage);
      final page = MainShellLifecycle.currentPage!;
      final restoredItem = AvesNavItem(
        route: page.route,
        filters: page.filters,
        path: page.path,
      );

      expect(MainShellPage.canHost(items, allMedia), isTrue);
      expect(
        MainShellPage.preferredIndex(items, previous: restoredItem, home: allMedia),
        1,
      );
    });

    test('standalone page context only notifies when its identity changes', () {
      var notifications = 0;
      void listener() => notifications++;
      MainShellLifecycle.pageContext.addListener(listener);
      addTearDown(() {
        MainShellLifecycle.pageContext.removeListener(listener);
        MainShellLifecycle.clearPage();
      });

      MainShellLifecycle.updatePage(
        route: CollectionPage.routeName,
        filters: {FavouriteFilter.instance},
      );
      MainShellLifecycle.updatePage(
        route: CollectionPage.routeName,
        filters: {FavouriteFilter.instance},
      );
      expect(notifications, 1);

      MainShellLifecycle.updatePage(route: AlbumListPage.routeName);
      expect(notifications, 2);
    });

    test('shell eligibility rejects disabled skin, TV layout and non-hostable values', () {
      final items = [allMedia, albums];
      expect(
        MainShellPage.canUseShell(
          useMiuixUi: true,
          useTvLayout: false,
          items: items,
          home: allMedia,
          index: 0,
        ),
        isTrue,
      );
      expect(
        MainShellPage.canUseShell(
          useMiuixUi: false,
          useTvLayout: false,
          items: items,
          home: allMedia,
          index: 0,
        ),
        isFalse,
      );
      expect(
        MainShellPage.canUseShell(
          useMiuixUi: true,
          useTvLayout: true,
          items: items,
          home: allMedia,
          index: 0,
        ),
        isFalse,
      );
      expect(
        MainShellPage.canHost(
          const [
            AvesNavItem(route: HomePage.routeName),
            AvesNavItem(route: SearchPage.routeName),
          ],
          const AvesNavItem(route: HomePage.routeName),
        ),
        isFalse,
      );
    });
  });

  group('drawer tiles with a mounted shell', () {
    testWidgets('page tile asks the shell to switch instead of navigating', (tester) async {
      final shell = _FakeShell(hosted: {AlbumListPage.routeName});
      shell.activate();
      addTearDown(shell.deactivate);

      await _pushTile(
        tester,
        const PageNavTile(
          navItem: AvesNavItem(route: AlbumListPage.routeName),
          leading: SizedBox(),
          title: Text('albums'),
        ),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(shell.calls, [AlbumListPage.routeName]);
      // the tile popped itself and pushed nothing: we are back on the shell
      expect(find.text('shell'), findsOneWidget);
    });

    testWidgets('collection tile asks the shell to apply the filters in place', (tester) async {
      final shell = _FakeShell(hosted: {CollectionPage.routeName});
      shell.activate();
      addTearDown(shell.deactivate);

      await _pushTile(
        tester,
        CollectionNavTile(
          leading: const SizedBox(),
          title: const Text('collection'),
          filters: null,
          isSelected: () => false,
        ),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(shell.calls, [CollectionPage.routeName]);
      expect(find.text('shell'), findsOneWidget);
    });
  });
}
