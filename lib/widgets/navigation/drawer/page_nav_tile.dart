import 'dart:async';

import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/providers/shell_tab_provider.dart';
import 'package:aves/widgets/navigation/drawer/tile.dart';
import 'package:aves/widgets/navigation/nav_item.dart';
import 'package:material_ui/material_ui.dart';

typedef TileRouteBuilder = Route Function(BuildContext context, String routeName, bool topLevel);

class const PageNavTile({
  super.key,
  final Widget? leading,
  final Widget? title,
  final Widget? trailing,
  required final AvesNavItem navItem,
  final bool Function()? isSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final routeName = navItem.route;
    return SafeArea(
      top: false,
      bottom: false,
      child: ListTile(
        // key is expected by test driver
        key: Key('$routeName-tile'),
        leading: leading ?? DrawerPageIcon(route: routeName),
        title: title ?? DrawerPageTitle(route: routeName),
        trailing: trailing != null
            ? Builder(
                builder: (context) => DefaultTextStyle.merge(
                  style: TextStyle(
                    color: IconTheme.of(context).color!.withValues(alpha: .6),
                  ),
                  child: trailing!,
                ),
              )
            : null,
        onTap: () {
          Navigator.maybeOf(context)?.pop();
          // baicha fork: a destination hosted by the Miuix shell must be reached
          // *through* the shell. `goTo` replaces the whole route stack
          // (`pushAndRemoveUntil`), which destroys the shell and its persistent bottom
          // bar; destinations the shell does not host are pushed on top of it instead,
          // so the shell survives either way.
          final shell = ShellNavigation.current;
          if (shell != null) {
            if (shell.goTo(routeName)) return;
            unawaited(Navigator.maybeOf(context)?.push(navItem.routeBuilder(context, topLevel: false)));
            return;
          }
          navItem.goTo(context);
        },
        selected: context.currentRouteName == routeName && (isSelected?.call() ?? true),
      ),
    );
  }
}
