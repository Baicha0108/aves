import 'package:aves/model/filters/filters.dart';
import 'package:collection/collection.dart';
import 'package:material_ui/material_ui.dart';

/// A top-level destination that can be restored when the main shell is mounted.
class MainShellPageContext {
  final String route;
  final Set<CollectionFilter>? filters;
  final String? path;

  const new({
    required this.route,
    this.filters,
    this.path,
  });

  @override
  bool operator ==(Object other) {
    return other is MainShellPageContext && other.route == route && other.path == path && const SetEquality<CollectionFilter>().equals(other.filters, filters);
  }

  @override
  int get hashCode => Object.hash(route, path, const SetEquality<CollectionFilter>().hash(filters));
}

/// Tracks the current standalone page so the main shell can be restored after
/// its navigation configuration temporarily becomes invalid.
///
/// The bottom bar publishes the active destination while it is mounted. AvesApp
/// combines this with the current route and settings to decide when mounting the
/// shell is both possible and safe. Keeping this state outside `MainShellPage`
/// matters because the shell is disposed before the configuration becomes valid
/// again, so it cannot observe the recovery itself.
class MainShellLifecycle {
  static final ValueNotifier<MainShellPageContext?> pageContext = ValueNotifier(null);

  static MainShellPageContext? get currentPage => pageContext.value;

  static void updatePage({
    required String route,
    Set<CollectionFilter>? filters,
    String? path,
  }) {
    pageContext.value = MainShellPageContext(
      route: route,
      filters: filters == null ? null : Set.unmodifiable(filters),
      path: path,
    );
  }

  static void clearPage() => pageContext.value = null;
}
