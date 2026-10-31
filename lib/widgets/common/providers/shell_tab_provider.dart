import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:flutter/widgets.dart';

/// Exposes the route name of a tab hosted by the main shell
/// (see `MainShellPage`).
///
/// Inside the shell all tabs live in a single route, so `ModalRoute` can no longer
/// tell which page is on screen. Widgets that branch on `context.currentRouteName`
/// (drawer highlight, per-route settings, …) consult this scope instead, so they keep
/// behaving as if each tab still had its own route.
///
/// The shell installs it at **two** levels:
/// * one around the whole scaffold, carrying the route of the **active** tab — for
///   widgets that live outside the pager and must follow the current destination
///   (the bottom bar, the drawer tiles, the navigation rail);
/// * one per page slot inside the pager, carrying that page's **own** route — so a
///   lazily built page never reads another tab's per-route settings.
class ShellTabScope extends InheritedWidget {
  const new({
    super.key,
    required this.routeName,
    required super.child,
  });

  final String routeName;

  static String? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellTabScope>()?.routeName;

  @override
  bool updateShouldNotify(ShellTabScope oldWidget) => routeName != oldWidget.routeName;
}

/// Lets a page hosted by the main shell publish its [CollectionLens] to the shell.
///
/// The shell owns the drawer (so that it is drawn above the bottom bar and animates
/// outside the `PageView`), and the drawer needs the *active* tab's collection to
/// highlight the current filters.
class ShellCollectionSlot extends InheritedWidget {
  const new({
    super.key,
    required this.index,
    required this.register,
    required super.child,
  });

  /// Index of this tab in the shell.
  final int index;

  /// Called by the hosted page once, with its collection lens.
  final ValueChanged<CollectionLens> register;

  /// Looked up without creating a dependency: registering must not rebuild the page
  /// on every shell rebuild.
  static ShellCollectionSlot? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<ShellCollectionSlot>();

  @override
  bool updateShouldNotify(ShellCollectionSlot oldWidget) => index != oldWidget.index;
}

/// Gives hosted pages a way to open the **shell's** drawer.
///
/// Pages used to call `Scaffold.of(context).openDrawer()`, which resolves to their own
/// scaffold. Inside the shell the drawer lives on the shell's scaffold (so that it is
/// drawn above the bottom bar), hence this scope.
class ShellScaffoldScope extends InheritedWidget {
  const new({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  final VoidCallback openDrawer;

  static ShellScaffoldScope? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<ShellScaffoldScope>();

  @override
  bool updateShouldNotify(ShellScaffoldScope oldWidget) => false;
}

/// Gives every page hosted by the main shell the `PrimaryScrollController` semantics a
/// standalone page gets from its own route.
///
/// `ModalRoute` installs **one `PrimaryScrollController` per route**, and Aves pages take
/// their grid's controller from it (`PrimaryScrollController.of(context)`: the collection
/// grid, the filter grids, the explorer…). Inside the shell all tabs share a single route,
/// so without this scope every hosted page attaches its own `ScrollPosition` to that
/// **same** controller — and `ScrollController.position` only works with exactly one
/// attached position (`assert(_positions.length == 1)` in debug, `Too many elements` in
/// release). Reading `offset` then throws, which silently breaks everything that consults
/// it: notably the long press selection gesture of any page built *after* the first tab
/// (`GridSelectionGestureDetector._getItemAt` reads `scrollController.offset`), and the
/// per page scroll state (all tabs would scroll together).
class ShellTabScrollScope extends StatefulWidget {
  const new({super.key, required this.child});

  final Widget child;

  @override
  State<ShellTabScrollScope> createState() => _ShellTabScrollScopeState();
}

class _ShellTabScrollScopeState extends State<ShellTabScrollScope> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PrimaryScrollController(
    controller: _scrollController,
    child: widget.child,
  );
}

/// Lets a widget change the shell's destination **from anywhere**, instead of
/// replacing the whole route stack.
///
/// Aves normally navigates a top level destination with
/// `Navigator.pushAndRemoveUntil(route, (route) => false)`, which destroys every route
/// below — including the shell. That is why tapping a drawer entry used to leave a
/// standalone page behind: the bottom bar lost its persistent behaviour (tab
/// keep-alive, animated indicator) and the shell never came back.
///
/// The shell installs itself here while it is mounted ([activate] / [deactivate]).
/// A plain registry (rather than an `InheritedWidget`) is used on purpose: callers can
/// also live in a route pushed *above* the shell (the tags/countries pages opened from
/// the drawer, and their bottom bar), and such a route is not part of the shell's
/// widget tree, so no scope would reach it.
///
/// In the Material skin no shell is ever mounted, so this stays `null` and every caller
/// keeps the upstream navigation behaviour — as required by the first principle.
class ShellNavigation {
  const new({
    required this.routes,
    required this.switchTo,
    this.openOverShell,
  });

  /// Routes hosted by the shell, in bottom bar order.
  final List<String> routes;

  /// Switches the shell to [route], applying [filters] to that tab's collection when it
  /// is a collection destination. Returns whether the shell hosts [route].
  final bool Function(String route, Set<CollectionFilter>? filters) switchTo;

  /// Pushes a destination above the shell while preserving the shell and its tabs.
  ///
  /// Opens a destination above the shell while preserving the shell and its tabs.
  final bool Function(
    String route,
    Set<CollectionFilter>? filters,
    String? path,
    CollectionLens? currentCollection,
  )?
  openOverShell;

  static ShellNavigation? _current;

  /// The mounted shell, if any.
  static ShellNavigation? get current => _current;

  void activate() => _current = this;

  void deactivate() {
    if (identical(_current, this)) {
      _current = null;
    }
  }

  /// Whether the shell hosts [route] as one of its tabs.
  bool hosts(String route) => routes.contains(route);

  /// Asks the shell to show [route]. Returns `false` when the shell does not host it,
  /// in which case the caller must navigate the usual way.
  bool goTo(String route, {Set<CollectionFilter>? filters}) => switchTo(route, filters);

  /// Opens [route] above the mounted shell. Returns whether a shell accepted it.
  bool openOver(
    String route, {
    Set<CollectionFilter>? filters,
    String? path,
    CollectionLens? currentCollection,
  }) => openOverShell?.call(route, filters, path, currentCollection) ?? false;
}
