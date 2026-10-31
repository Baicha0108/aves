import 'dart:math';

import 'package:aves/app_mode.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/settings/enums/miuix_bottom_bar_alignment.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/widgets/collection/collection_page.dart';
import 'package:aves/widgets/common/bars/floating_bar.dart';
import 'package:aves/widgets/common/basic/draggable_scrollbar/notifications.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/extensions/media_query.dart';
import 'package:aves/widgets/common/providers/shell_tab_provider.dart';
import 'package:aves/widgets/navigation/main_shell_lifecycle.dart';
import 'package:aves/widgets/navigation/nav_bar/floating.dart';
import 'package:aves/widgets/navigation/nav_item.dart';
import 'package:aves_miuix/aves_miuix.dart';
import 'package:collection/collection.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class const AppBottomNavBar({
  super.key,
  required final Stream<DraggableScrollbarEvent> events,
  // collection loaded in the `CollectionPage`, if any
  final CollectionLens? currentCollection,
  // baicha fork: when the bar is hosted by the main shell, the shell owns both the
  // selected index and the tab switch, and the bar stays visible while scrolling
  // (KSU-style persistent bar) instead of sliding away.
  final int? indexOverride,
  final ValueChanged<int>? onSelectedOverride,
  final bool persistent = false,
}) extends StatefulWidget {
  static EdgeInsets getMargin(double safeBottomPadding) {
    return EdgeInsets.only(left: 8, top: 8, right: 8, bottom: max(8, safeBottomPadding + 4));
  }

  static double getHeightWithMargin(double safeBottomPadding) {
    // baicha fork: this is the **upstream formula**, and it must stay independent of the
    // skin. The Miuix pill is drawn inside the very same slot instead of growing the bar,
    // so switching skins never shifts the bar or the content padding.
    return kBottomNavigationBarHeight + getMargin(safeBottomPadding).vertical;
  }

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar> {
  String? _lastRoute;

  @override
  void initState() {
    super.initState();
    _registerWidget(widget);
  }

  @override
  void didUpdateWidget(covariant AppBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unregisterWidget(oldWidget);
    _registerWidget(widget);
  }

  @override
  void dispose() {
    _unregisterWidget(widget);
    super.dispose();
  }

  void _registerWidget(AppBottomNavBar widget) {
    widget.currentCollection?.filterChangeNotifier.addListener(_onCollectionFilterChanged);
  }

  void _unregisterWidget(AppBottomNavBar widget) {
    widget.currentCollection?.filterChangeNotifier.removeListener(_onCollectionFilterChanged);
  }

  @override
  Widget build(BuildContext context) {
    final items = context.select<Settings, List<AvesNavItem>>((v) => v.bottomNavigationActions);
    if (items.length < 2) return const SizedBox();

    final safeBottomPadding = context.select<MediaQueryData, double>((mq) => mq.safeBottomPadding);
    final useMiuixUi = settings.useMiuixUi;
    final miuixBarAlignment = context.select<Settings, MiuixBottomBarAlignment>((v) => v.miuixBottomBarAlignment);
    final currentItem = widget.indexOverride == null ? _getCurrentItem(context, items) : null;
    final currentIndex = widget.indexOverride ?? (currentItem == null ? 0 : items.indexOf(currentItem));
    if (ShellNavigation.current == null && currentItem != null && currentItem.route == _lastRoute) {
      MainShellLifecycle.updatePage(
        route: currentItem.route,
        filters: widget.currentCollection?.filters ?? currentItem.filters,
        path: currentItem.path,
      );
    }
    final barContent = SafeArea(
      bottom: false,
      child: MediaQuery.removePadding(
        context: context,
        // `bottom` is computed beforehand and used in multiple places,
        // so we remove it from context to prevent additional padding
        removeBottom: true,
        child: useMiuixUi
            // KSU 风格悬浮底栏：胶囊 + 图标 + 11sp 文字 + 滑动选中指示器。
            // SizedBox 用的是上游给底栏的高度，胶囊在其中居中，因此占位与原版一致。
            ? SizedBox(
                height: AppBottomNavBar.getHeightWithMargin(safeBottomPadding),
                child: Align(
                  alignment: Alignment.center,
                  child: AvesMiuixBottomBar(
                    alignment: _getMiuixBarAlignment(miuixBarAlignment),
                    currentIndex: currentIndex,
                    onSelected: (index) => _onTabTap(context, items, index),
                    items: [
                      for (final item in items)
                        AvesMiuixBottomBarItem(
                          icon: item.getIcon(context),
                          label: item.getText(context),
                        ),
                    ],
                  ),
                ),
              )
            : AvesFloatingBar(
                margin: AppBottomNavBar.getMargin(safeBottomPadding),
                builder: (context, backgroundColor, child) => BottomNavigationBar(
                  items: items.map((item) {
                    final label = item.getText(context);
                    return BottomNavigationBarItem(
                      icon: item.getIcon(context),
                      label: label,
                      tooltip: label,
                    );
                  }).toList(),
                  onTap: (index) => _onTabTap(context, items, index),
                  currentIndex: currentIndex,
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: backgroundColor,
                  showSelectedLabels: false,
                  showUnselectedLabels: false,
                ),
              ),
      ),
    );
    Widget child = widget.persistent
        ? barContent
        : FloatingNavBar(
            scrollController: PrimaryScrollController.of(context),
            events: widget.events,
            childHeight: AppBottomNavBar.getHeightWithMargin(safeBottomPadding),
            child: barContent,
          );

    final animate = context.select<Settings, bool>((v) => v.animate);
    // baicha fork: under the Miuix skin the bar is kept alive across tab switches
    // (see `_goTo`), so the Hero flight is not needed — and it would fight the
    // indicator's own slide animation.
    if (animate && !useMiuixUi) {
      child = Hero(
        tag: 'nav-bar',
        flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
          return MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: toHeroContext.widget,
          );
        },
        child: child,
      );
    }

    return child;
  }

  void _onCollectionFilterChanged() => setState(() {});

  Alignment _getMiuixBarAlignment(MiuixBottomBarAlignment alignment) {
    return switch (alignment) {
      .left => Alignment.centerLeft,
      .center => Alignment.center,
      .right => Alignment.centerRight,
    };
  }

  /// The shell (when present) owns the tab switch; otherwise fall back to navigation.
  void _onTabTap(BuildContext context, List<AvesNavItem> items, int index) {
    final override = widget.onSelectedOverride;
    if (override != null) {
      override(index);
    } else {
      _goTo(context, items, index);
    }
  }

  AvesNavItem? _getCurrentItem(BuildContext context, List<AvesNavItem> items) {
    // current route may be null during navigation
    final currentRoute = context.currentRouteName ?? _lastRoute;
    _lastRoute = currentRoute;

    return items.firstWhereOrNull((item) {
      final itemRoute = item.route;
      if (currentRoute != itemRoute) return false;

      switch (itemRoute) {
        case CollectionPage.routeName:
          final currentFilters = widget.currentCollection?.filters ?? {};
          return const SetEquality().equals(currentFilters, item.filters ?? {});
        default:
          return true;
      }
    });
  }

  void _goTo(BuildContext context, List<AvesNavItem> items, int index) {
    final item = items[index];
    // baicha fork: the Miuix shell owns the destinations it hosts, and switching
    // through it keeps the shell (and this persistent bar) alive. `goTo` below would
    // replace the whole route stack and destroy both — which is what used to happen
    // when the bar was tapped on a page pushed above the shell.
    final shell = ShellNavigation.current;
    if (shell != null && shell.goTo(item.route, filters: item.filters)) {
      return;
    }
    if (shell != null && !item.isHostable) {
      final opened = shell.openOver(
        item.route,
        filters: item.filters,
        path: item.path,
        currentCollection: widget.currentCollection,
      );
      if (opened) return;
    }
    // baicha fork: Miuix skin → switch between collection tabs **in place**.
    // Aves normally replaces the whole route stack (`pushAndRemoveUntil`), which
    // destroys the page and the bottom bar: the indicator could never animate and
    // every tap rebuilt a page (slow, and worse when tapping quickly).
    if (settings.useMiuixUi && item.route == CollectionPage.routeName) {
      final collection = widget.currentCollection;
      if (collection != null && context.currentRouteName == CollectionPage.routeName) {
        collection.setFilters(item.filters ?? const <CollectionFilter>{});
        return;
      }
    }
    item.goTo(context, topLevel: null);
  }
}

class const NavBarPaddingSliver({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final canNavigate = context.select<ValueNotifier<AppMode>, bool>((v) => v.value.canNavigate);
    final enableBottomNavigationBar = context.select<Settings, bool>((v) => v.enableBottomNavigationBar);
    final safeBottomPadding = context.select<MediaQueryData, double>((mq) => mq.safeBottomPadding);
    final showBottomNavigationBar = canNavigate && enableBottomNavigationBar;
    final height = showBottomNavigationBar ? AppBottomNavBar.getHeightWithMargin(safeBottomPadding) : safeBottomPadding;
    return SliverToBoxAdapter(
      child: SizedBox(height: height),
    );
  }
}
