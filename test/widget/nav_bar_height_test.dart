import 'package:aves/widgets/navigation/nav_bar/nav_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The Miuix pill must stay inside upstream's bottom-navigation layout slot.
void main() {
  double upstreamHeight(double safeBottomPadding) => kBottomNavigationBarHeight + AppBottomNavBar.getMargin(safeBottomPadding).vertical;

  group('bottom bar keeps the upstream layout slot', () {
    for (final safeBottomPadding in [0.0, 24.0, 34.0, 48.0]) {
      test('height == upstream formula (safeBottomPadding=$safeBottomPadding)', () {
        expect(AppBottomNavBar.getHeightWithMargin(safeBottomPadding), upstreamHeight(safeBottomPadding));
      });
    }

    test('margin is the upstream margin', () {
      expect(AppBottomNavBar.getMargin(0), const EdgeInsets.only(left: 8, top: 8, right: 8, bottom: 8));
      expect(AppBottomNavBar.getMargin(24), const EdgeInsets.only(left: 8, top: 8, right: 8, bottom: 28));
    });
  });
}
