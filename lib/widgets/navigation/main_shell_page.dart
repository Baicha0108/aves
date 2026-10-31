import 'dart:async';
import 'dart:math' as math;

import 'package:aves/app_mode.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/widgets/collection/collection_page.dart';
import 'package:aves/widgets/common/basic/draggable_scrollbar/notifications.dart';
import 'package:aves/widgets/common/basic/scaffold.dart';
import 'package:aves/widgets/common/behaviour/app_route_observer.dart';
import 'package:aves/widgets/common/extensions/media_query.dart';
import 'package:aves/widgets/common/providers/shell_tab_provider.dart';
import 'package:aves/widgets/navigation/nav_bar/nav_bar.dart';
import 'package:aves/widgets/navigation/main_shell_lifecycle.dart';
import 'package:aves/widgets/navigation/nav_item.dart';
import 'package:aves/widgets/navigation/drawer/app_drawer.dart';
import 'package:aves_model/aves_model.dart';
import 'package:collection/collection.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// Main navigation shell for the Miuix skin.
///
/// Aves normally switches destinations by replacing the whole route stack
/// (`Navigator.pushAndRemoveUntil`), which destroys the page *and* the bottom bar:
/// the bar could never animate its indicator, and every tap rebuilt a page.
///
/// This shell keeps the bottom bar alive and hosts the destinations of the bottom
/// navigation in a [PageView], so switching a tab is a slide between pages —
/// the KSU/Miuix behaviour (persistent bar, animated indicator, kept-alive pages).
class MainShellPage extends StatefulWidget {
  static const routeName = '/main-shell';

  final AvesNavItem? initialItem;

  const new({
    super.key,
    this.initialItem,
  });

  /// Index of the bottom navigation item representing [home].
  ///
  /// Collection destinations must match both route and filters: with multiple
  /// collection tabs, matching only `/collection` would silently select the wrong
  /// tab (and ignore a custom home collection).
  static int homeIndexFor(List<AvesNavItem> items, AvesNavItem home) {
    const equality = SetEquality<CollectionFilter>();
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      if (item.route != home.route || item.path != home.path) continue;
      if (item.route == CollectionPage.routeName && !equality.equals(item.filters ?? const <CollectionFilter>{}, home.filters ?? const <CollectionFilter>{})) {
        continue;
      }
      return index;
    }
    return -1;
  }

  /// Whether the persistent shell can represent the current bottom navigation.
  static bool canHost(List<AvesNavItem> items, AvesNavItem home) {
    if (items.length < 2 || items.every((item) => !item.isHostable)) return false;
    final homeIndex = homeIndexFor(items, home);
    return homeIndex >= 0 && items[homeIndex].isHostable;
  }

  /// Whether the mounted shell is still valid for the current app configuration.
  static bool canUseShell({
    required bool useMiuixUi,
    required bool useTvLayout,
    required List<AvesNavItem> items,
    required AvesNavItem home,
    required int index,
  }) {
    if (!useMiuixUi || useTvLayout || !canHost(items, home)) return false;
    return index >= 0 && index < items.length && items[index].isHostable;
  }

  static int indexOfItem(List<AvesNavItem> items, AvesNavItem target) {
    const equality = SetEquality<CollectionFilter>();
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      if (item.route != target.route || item.path != target.path) continue;
      if (item.route == CollectionPage.routeName && !equality.equals(item.filters ?? const <CollectionFilter>{}, target.filters ?? const <CollectionFilter>{})) {
        continue;
      }
      return index;
    }
    return -1;
  }

  /// Resolves the selected index after a navigation configuration change.
  ///
  /// It first preserves the previously selected destination, then the configured
  /// home destination, and finally falls back to the first hostable tab.
  static int preferredIndex(
    List<AvesNavItem> items, {
    AvesNavItem? previous,
    required AvesNavItem home,
  }) {
    var index = previous == null ? -1 : indexOfItem(items, previous);
    if (index < 0) index = homeIndexFor(items, home);
    if (index < 0 || !items[index].isHostable) {
      index = items.indexWhere((item) => item.isHostable);
    }
    return index >= 0 ? index : 0;
  }

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> with RouteAware {
  late List<AvesNavItem> _items;
  late PageController _pageController;
  late ShellNavigation _navigation;
  StreamSubscription? _settingsSubscription;
  PageRoute? _route;
  final Map<int, CollectionLens> _collections = {};
  // 0 = fully visible, 1 = fully hidden (translated down by its own height)
  final ValueNotifier<double> _barOffset = ValueNotifier(0);
  // filters requested for a collection tab that has not been built yet
  Set<CollectionFilter>? _pendingFilters;
  int? _pendingFiltersIndex;
  List<Widget>? _pages;
  late int _index;
  double _barHeight = 0;
  bool _exitPending = false;
  bool _exiting = false;

  static const _transitionDuration = Duration(milliseconds: 260);
  static const _transitionCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    _items = List.unmodifiable(settings.bottomNavigationActions);
    _index = MainShellPage.preferredIndex(
      _items,
      previous: widget.initialItem,
      home: settings.homeNavItem,
    );
    _pageController = PageController(initialPage: _index);
    _navigation = _createNavigation(_items);
    MainShellLifecycle.clearPage();
    _navigation.activate();
    _settingsSubscription = settings.updateStream.listen(_onSettingsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _enforceShellEligibility());
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    appRouteObserver.unsubscribe(this);
    _navigation.deactivate();
    _pageController.dispose();
    _barOffset.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    appRouteObserver.unsubscribe(this);
    _route = route is PageRoute ? route : null;
    if (_route != null) {
      appRouteObserver.subscribe(this, _route!);
    }
  }

  @override
  void didPopNext() {
    if (_exitPending) {
      _enforceShellEligibility();
    }
  }

  @override
  Widget build(BuildContext context) {
    // built once and kept alive, so each tab keeps its scroll position and state
    _pages ??= [
      for (var index = 0; index < _items.length; index++)
        if (!_items[index].isHostable)
          const SizedBox.shrink()
        else
          _ShellTab(
            key: ValueKey('shell-tab-$index-${_items[index].toJson()}'),
            // Every hosted page advertises **its own** route name. The scope above the
            // scaffold advertises the *active* tab, which is what the drawer and the
            // bottom bar need — but a page is built while another tab may be active
            // (the `PageView` builds lazily), and its per-route settings (tile extent,
            // title query, sort factor) must not be keyed to whatever tab that was.
            child: ShellTabScrollScope(
              // All tabs live in one route, so they would otherwise attach their scroll
              // positions to the *same* `PrimaryScrollController` (see the class doc) —
              // which breaks long press selection and per-tab scrolling.
              child: ShellTabScope(
                routeName: _items[index].route,
                child: ShellCollectionSlot(
                  index: index,
                  register: (collection) => _registerCollection(index, collection),
                  child: _items[index].pageBuilder(context),
                ),
              ),
            ),
          ),
    ];

    final canNavigate = context.select<ValueNotifier<AppMode>, bool>((v) => v.value.canNavigate);
    _barHeight = AppBottomNavBar.getHeightWithMargin(context.select<MediaQueryData, double>((mq) => mq.safeBottomPadding));

    final currentItem = _itemAt(_index) ?? settings.homeNavItem;
    return ShellTabScope(
      routeName: currentItem.route,
      child: AvesScaffold(
        body: Builder(
          // the drawer belongs to the shell, so hosted pages must open this one
          builder: (scaffoldContext) => ShellScaffoldScope(
            openDrawer: () => Scaffold.of(scaffoldContext).openDrawer(),
            // The bar's hide-on-scroll must follow the **hosted pages** only: the
            // scaffold also hosts the drawer, and listening above it made the drawer's
            // own list — or any other scrollable of the scaffold — slide the bar away
            // behind the open drawer.
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: PageView(
                controller: _pageController,
                // Tab switching is done through the bottom bar only: keeping the
                // horizontal swipe would steal gestures from in-page controls —
                // notably Aves' draggable scrollbar thumb (a vertical drag at the
                // right edge), which then cannot be dragged at all.
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  final item = _itemAt(index);
                  if (item == null || !item.isHostable) return;
                  if (_index != index) {
                    setState(() => _index = index);
                    _barOffset.value = 0;
                  }
                },
                children: _pages!,
              ),
            ),
          ),
        ),
        // the drawer belongs to the shell: Flutter draws it above the bottom bar
        // (and it animates outside the `PageView`), matching the original behaviour
        drawer: canNavigate ? AppDrawer(currentCollection: _collections[_index]) : null,
        // the bar is persistent here (no hide-on-scroll wrapper): it belongs to the
        // shell, not to the page, which is what makes the indicator animation continuous
        bottomNavigationBar: ValueListenableBuilder<double>(
          valueListenable: _barOffset,
          builder: (context, offset, child) => FractionalTranslation(
            translation: Offset(0, offset),
            child: child,
          ),
          child: AppBottomNavBar(
            events: const Stream<DraggableScrollbarEvent>.empty(),
            indexOverride: _index,
            onSelectedOverride: _onTabSelected,
            persistent: true,
          ),
        ),
        resizeToAvoidBottomInset: false,
        extendBody: true,
      ),
    );
  }

  AvesNavItem? _itemAt(int index) => index >= 0 && index < _items.length ? _items[index] : null;

  ShellNavigation _createNavigation(List<AvesNavItem> items) => ShellNavigation(
    routes: [
      for (final item in items)
        if (item.isHostable) item.route,
    ],
    switchTo: _switchTo,
    openOverShell: (route, filters, path, currentCollection) {
      if (!mounted) return false;
      return _openOverShell(
        AvesNavItem(route: route, filters: filters, path: path),
        currentCollection: currentCollection,
      );
    },
  );

  void _onSettingsChanged(SettingsChangedEvent event) {
    final key = event.key;
    if (key == SettingKeys.bottomNavigationActionsKey) {
      _resetNavigation(settings.bottomNavigationActions);
    } else if (key == SettingKeys.useMiuixUiKey) {
      _exitPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _enforceShellEligibility());
    }
  }

  void _resetNavigation(List<AvesNavItem> items) {
    if (!mounted) return;
    final previousItem = _itemAt(_index);
    final newItems = List<AvesNavItem>.unmodifiable(items);
    final nextIndex = MainShellPage.preferredIndex(
      newItems,
      previous: previousItem,
      home: settings.homeNavItem,
    );

    final oldController = _pageController;
    final oldNavigation = _navigation;
    final newNavigation = _createNavigation(newItems);

    setState(() {
      _items = newItems;
      _index = nextIndex;
      _pageController = PageController(initialPage: nextIndex);
      _navigation = newNavigation;
      _pages = null;
      _collections.clear();
      _pendingFilters = null;
      _pendingFiltersIndex = null;
      _barOffset.value = 0;
    });

    newNavigation.activate();
    oldNavigation.deactivate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldController.dispose();
      _enforceShellEligibility();
    });
  }

  bool get _isShellEligible {
    return MainShellPage.canUseShell(
      useMiuixUi: settings.useMiuixUi,
      useTvLayout: settings.useTvLayout,
      items: _items,
      home: settings.homeNavItem,
      index: _index,
    );
  }

  void _enforceShellEligibility() {
    if (!mounted || _exiting) return;
    if (_isShellEligible) {
      _exitPending = false;
      return;
    }
    final route = _route ?? (ModalRoute.of(context) as PageRoute?);
    if (route == null || !route.isCurrent) {
      _exitPending = true;
      return;
    }
    _exitPending = false;
    _exitShell();
  }

  void _exitShell() {
    if (_exiting) return;
    _exiting = true;

    final activeItem = _itemAt(_index);
    final item = activeItem?.isHostable == true ? activeItem! : settings.homeNavItem;
    final collection = item.route == CollectionPage.routeName && activeItem?.isHostable == true ? _collections[_index] : null;
    final effectiveItem = collection == null ? item : AvesNavItem(route: item.route, filters: collection.filters, path: item.path);
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) {
      _exiting = false;
      return;
    }
    unawaited(
      navigator.pushAndRemoveUntil(
        effectiveItem.routeBuilder(
          context,
          topLevel: true,
          currentCollection: collection,
        ),
        (_) => false,
      ),
    );
  }

  bool _openOverShell(AvesNavItem item, {CollectionLens? currentCollection}) {
    if (item.isHostable) return false;
    final collection = currentCollection ?? _collections[_index];
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return false;
    navigator.push(
      item.routeBuilder(
        context,
        topLevel: false,
        currentCollection: collection,
      ),
    );
    return true;
  }

  void _registerCollection(int index, CollectionLens collection) {
    _collections[index] = collection;
    if (_pendingFiltersIndex == index) {
      final pending = _pendingFilters!;
      _pendingFilters = null;
      _pendingFiltersIndex = null;
      // registration happens while the page builds, so defer the notification
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          collection.setFilters(pending);
        }
      });
    }
    if (index == _index) {
      // registration happens while the page builds, so defer the rebuild
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && index == _index) {
          // the drawer needs the freshly registered collection of the active tab
          setState(() {});
        }
      });
    }
  }

  /// Tab index for [route], preferring the tab that already carries exactly [filters]
  /// (so that the drawer's "all media" entry selects the "all media" tab rather than
  /// reusing whichever collection tab happens to come first).
  int _indexOfRoute(String route, Set<CollectionFilter>? filters) {
    if (route == CollectionPage.routeName) {
      const equality = SetEquality<CollectionFilter>();
      final wanted = filters ?? const <CollectionFilter>{};
      final exact = _items.indexWhere((item) => item.route == route && equality.equals(item.filters ?? const <CollectionFilter>{}, wanted));
      if (exact >= 0) return exact;
    }
    return _items.indexWhere((item) => item.route == route);
  }

  void _applyFilters(int index, String route, Set<CollectionFilter>? filters) {
    if (route != CollectionPage.routeName) return;
    final wanted = filters ?? const <CollectionFilter>{};
    final collection = _collections[index];
    if (collection != null) {
      collection.setFilters(wanted);
    } else {
      // the tab has not been built yet: apply the filters as soon as it registers
      _pendingFilters = wanted;
      _pendingFiltersIndex = index;
    }
  }

  /// Asks the shell to switch to [route]. Returns whether the shell hosts it.
  ///
  /// Called through [ShellNavigation] by the drawer tiles and by the bottom bar of any
  /// route pushed above the shell, so that neither of them has to replace the route
  /// stack (which used to destroy the shell, and with it the persistent bar).
  bool _switchTo(String route, Set<CollectionFilter>? filters) {
    final index = _indexOfRoute(route, filters);
    if (index < 0) return false;

    // a route pushed above the shell hides it: get back to it first, otherwise the tab
    // switch would happen off screen
    Navigator.maybeOf(context)?.popUntil((r) => r.settings.name == MainShellPage.routeName);

    _applyFilters(index, route, filters);

    if (index != _index) {
      setState(() => _index = index);
      _barOffset.value = 0;
      _pageController.animateToPage(index, duration: _transitionDuration, curve: _transitionCurve);
    }
    return true;
  }

  /// Hide-on-scroll, replicating Aves' `FloatingNavBar` behaviour at shell level
  /// (the bar is owned by the shell, so it cannot use the page's scroll controller).
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification) return false;
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return false;

    final delta = notification.scrollDelta ?? 0;
    if (delta == 0) return false;

    final childHeight = _barHeight > 0 ? _barHeight : AppBottomNavBar.getHeightWithMargin(0);
    final after = metrics.extentAfter;
    final double next;
    if (after < childHeight && delta > 0) {
      next = math.min(_barOffset.value, after / childHeight);
    } else {
      next = _barOffset.value + delta / childHeight;
    }
    _barOffset.value = next.clamp(0.0, 1.0);
    return false;
  }

  void _onTabSelected(int index) {
    final item = _itemAt(index);
    if (item != null && !item.isHostable) {
      _openOverShell(item);
      return;
    }
    if (index == _index) return;
    setState(() => _index = index);
    _barOffset.value = 0;
    _pageController.animateToPage(index, duration: _transitionDuration, curve: _transitionCurve);
  }
}

/// Keeps a shell tab (and everything below it) alive while it is off screen.
class _ShellTab extends StatefulWidget {
  const new({super.key, required this.child});

  final Widget child;

  @override
  State<_ShellTab> createState() => _ShellTabState();
}

class _ShellTabState extends State<_ShellTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
