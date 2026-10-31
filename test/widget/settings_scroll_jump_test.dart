import 'package:aves/l10n/l10n.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/theme/colors.dart';
import 'package:aves/theme/durations.dart';
import 'package:aves/widgets/settings/settings_mobile_page.dart';
import 'package:aves_miuix/aves_miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../common.dart';

void main() {
  setUpAll(() async {
    await setUpAllServices();
  });

  tearDownAll(() async {
    await tearDownAllServices();
  });

  setUp(() async {
    await setUpServices();
    settings.useMiuixUi = true;
  });

  testWidgets('Miuix settings keep scroll extent stable while Display is expanded', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => AvesMiuixTheme(enabled: true, child: child!),
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<Settings>.value(value: settings),
            Provider<DurationsData>.value(value: DurationsData()),
            Provider<MediaQueryData>.value(value: const MediaQueryData()),
          ],
          child: const AvesColorsProvider(
            child: SettingsMobilePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final display = find.byKey(const Key('section-display'), skipOffstage: false);
    await tester.scrollUntilVisible(display, 300);
    await tester.pumpAndSettle();
    await tester.tap(display);
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final initialExtent = scrollable.position.maxScrollExtent;
    final displayCard = find.byKey(const Key('tilecard-display'), skipOffstage: false);
    final expandedHeight = tester.getSize(displayCard).height;
    // The exact content height depends on which settings are available. What
    // matters is that this is clearly expanded and remains stable while scrolling.
    expect(expandedHeight, greaterThan(400));

    final gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
    for (var i = 1; i <= 10; i++) {
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump(const Duration(milliseconds: 16));
      expect(scrollable.position.maxScrollExtent, closeTo(initialExtent, .01));
      expect(tester.getSize(displayCard).height, closeTo(expandedHeight, .01));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
