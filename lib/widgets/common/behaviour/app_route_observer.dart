import 'package:material_ui/material_ui.dart';

/// Shared route observer for app-wide route lifecycle listeners.
///
/// Kept outside `AvesApp` so widgets below the navigator can subscribe without
/// importing the application root (which would create an avoidable import cycle).
class AppRouteObserver extends RouteObserver<PageRoute> {
  final ValueNotifier<PageRoute?> currentRoute = ValueNotifier(null);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      currentRoute.value = route;
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(route, currentRoute.value)) {
      currentRoute.value = previousRoute is PageRoute ? previousRoute : null;
    }
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      currentRoute.value = newRoute;
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(route, currentRoute.value)) {
      currentRoute.value = previousRoute is PageRoute ? previousRoute : null;
    }
    super.didRemove(route, previousRoute);
  }
}

final appRouteObserver = AppRouteObserver();
