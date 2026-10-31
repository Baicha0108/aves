import 'package:aves/model/settings/settings.dart';
import 'package:aves/widgets/navigation/nav_bar/nav_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../common.dart';

/// 底栏高度回归测试。
///
/// 原则（见 FORK.md）：**Material（MD）界面必须和上游 Aves 逐像素一致**，
/// 所有外观改动只能发生在 Miuix 皮肤这一侧。
///
/// 上游公式：`kBottomNavigationBarHeight + getMargin(safeBottomPadding).vertical`
/// 历史 bug：Miuix 分支返回 `barHeight + 28`，在无手势条时是 92dp，比原版 72dp 高 20dp，
/// 导致切到 Miuix 后底栏整体偏高。
void main() {
  setUpAll(() async {
    await setUpAllServices();
  });

  tearDownAll(() async {
    await tearDownAllServices();
  });

  late bool originalSetting;

  setUp(() async {
    await setUpServices();
    originalSetting = settings.useMiuixUi;
  });

  tearDown(() {
    settings.useMiuixUi = originalSetting;
  });

  double upstreamHeight(double safeBottomPadding) => kBottomNavigationBarHeight + AppBottomNavBar.getMargin(safeBottomPadding).vertical;

  group('MD UI must match upstream exactly', () {
    for (final safeBottomPadding in [0.0, 24.0, 34.0, 48.0]) {
      test('MD height == upstream formula (safeBottomPadding=$safeBottomPadding)', () {
        settings.useMiuixUi = false;
        expect(AppBottomNavBar.getHeightWithMargin(safeBottomPadding), upstreamHeight(safeBottomPadding));
      });
    }

    test('MD margin is the upstream margin', () {
      settings.useMiuixUi = false;
      expect(AppBottomNavBar.getMargin(0), const EdgeInsets.only(left: 8, top: 8, right: 8, bottom: 8));
      expect(AppBottomNavBar.getMargin(24), const EdgeInsets.only(left: 8, top: 8, right: 8, bottom: 28));
    });
  });

  group('Miuix bar must not make the bar taller than upstream', () {
    for (final safeBottomPadding in [0.0, 24.0, 34.0, 48.0]) {
      test('Miuix height == upstream formula (safeBottomPadding=$safeBottomPadding)', () {
        settings.useMiuixUi = true;
        expect(
          AppBottomNavBar.getHeightWithMargin(safeBottomPadding),
          upstreamHeight(safeBottomPadding),
          reason: 'Miuix 底栏占用的垂直空间必须与原版一致，否则切换皮肤时底栏会整体位移',
        );
      });
    }

    test('Miuix height is stable regardless of the skin toggle', () {
      for (final safeBottomPadding in [0.0, 24.0, 34.0]) {
        settings.useMiuixUi = false;
        final md = AppBottomNavBar.getHeightWithMargin(safeBottomPadding);
        settings.useMiuixUi = true;
        final miuix = AppBottomNavBar.getHeightWithMargin(safeBottomPadding);
        expect(miuix, md, reason: '切换皮肤不应改变底栏占位高度（safeBottomPadding=$safeBottomPadding）');
      }
    });
  });
}
