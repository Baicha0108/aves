import 'package:aves/widgets/common/behaviour/pop/scope.dart';
import 'package:aves/widgets/common/providers/shell_tab_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('inactive shell tabs do not register pop handlers', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    var blocked = 0;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('base')),
      ),
    );

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => ShellTabActiveScope(
          active: false,
          child: AvesPopScope(
            handlers: [
              APopHandler(
                canPop: (_) => false,
                onPopBlocked: (_) => blocked++,
              ),
            ],
            child: const Scaffold(body: Text('inactive tab')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    navigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();

    expect(blocked, 0);
    expect(find.text('base'), findsOneWidget);
  });

  testWidgets('inactive shell tabs do not contribute duplicate hero tags', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    const tag = 'shared-app-bar-title';

    Widget hero(String text) => Hero(
      tag: tag,
      child: Material(child: Text(text)),
    );

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Column(
          children: [
            HeroMode(enabled: false, child: hero('inactive')),
            HeroMode(enabled: true, child: hero('active')),
          ],
        ),
      ),
    );

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('next')),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('next'), findsOneWidget);
  });
}
