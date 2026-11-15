import 'package:aves/widgets/common/providers/shell_tab_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Resolves the primary scroll controller the way Aves' pages do, and binds it to a list.
class _PagedList extends StatelessWidget {
  const new({required this.onResolved});

  final ValueChanged<ScrollController> onResolved;

  @override
  Widget build(BuildContext context) {
    final controller = PrimaryScrollController.of(context);
    onResolved(controller);
    return ListView(
      controller: controller,
      children: const [SizedBox(height: 2000)],
    );
  }
}

void main() {
  /// Two pages in a single route, i.e. exactly how the shell hosts its tabs.
  Future<List<ScrollController>> pumpTabs(WidgetTester tester, {required bool scoped}) async {
    final resolved = <ScrollController>[];
    Widget tab() {
      final list = _PagedList(onResolved: resolved.add);
      return Expanded(child: scoped ? ShellTabScrollScope(child: list) : list);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(children: [tab(), tab()]),
        ),
      ),
    );
    return resolved;
  }

  testWidgets('each hosted page gets its own primary scroll controller', (tester) async {
    final controllers = await pumpTabs(tester, scoped: true);
    expect(controllers, hasLength(2));
    expect(controllers[0], isNot(same(controllers[1])));

    // reading `offset` throws as soon as one controller carries two attached positions,
    // and Aves' grid selection gesture reads it on every long press
    expect(controllers[0].offset, 0);
    expect(controllers[1].offset, 0);

    // tabs also scroll independently
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(controllers[0].offset, greaterThan(0));
    expect(controllers[1].offset, 0);
  });

  testWidgets('without the scope both tabs share the route controller (the bug)', (tester) async {
    final controllers = await pumpTabs(tester, scoped: false);
    expect(controllers[0], same(controllers[1]));
    // this is what silently broke long press selection on pages built after the first tab
    expect(() => controllers[0].offset, throwsA(anything));
  });
}
