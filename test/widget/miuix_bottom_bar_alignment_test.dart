import 'package:aves_miuix/aves_miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('Miuix bottom bar aligns the same sized surface left, center and right', (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final cases = {
      Alignment.centerLeft: AvesMiuixBottomBar.edgeInset,
      Alignment.center: 400.0,
      Alignment.centerRight: 800.0 - AvesMiuixBottomBar.edgeInset,
    };
    double? expectedWidth;

    for (final entry in cases.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          builder: (context, child) => AvesMiuixTheme(enabled: true, child: child!),
          home: Scaffold(
            body: AvesMiuixBottomBar(
              alignment: entry.key,
              currentIndex: 0,
              onSelected: (_) {},
              items: const [
                AvesMiuixBottomBarItem(icon: Icon(Icons.photo_library), label: 'One'),
                AvesMiuixBottomBarItem(icon: Icon(Icons.folder), label: 'Two'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final rect = tester.getRect(find.byKey(AvesMiuixBottomBar.surfaceKey));
      expectedWidth ??= rect.width;
      expect(rect.width, closeTo(expectedWidth, .01));
      if (entry.key == Alignment.centerLeft) {
        expect(rect.left, closeTo(entry.value, .01));
      } else if (entry.key == Alignment.center) {
        expect((rect.left + rect.right) / 2, closeTo(entry.value, .01));
      } else {
        expect(rect.right, closeTo(entry.value, .01));
      }
    }
  });
}
