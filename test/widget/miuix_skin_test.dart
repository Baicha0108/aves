import 'package:aves/widgets/miuix/miuix_sample_page.dart';
import 'package:aves_miuix/aves_miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Miuix 皮肤的最小回归测试：
/// 1. 开关打开时能挂载 MiuixTheme，并让样张页完整渲染（不抛异常）；
/// 2. 开关关闭时不会引入 Miuix 主题，即完全退回 aves 原生外观。
void main() {
  testWidgets('miuix skin mounts theme and renders sample page', (tester) async {
    // 用一块足够大的画布，让样张页所有分区都被构建（ListView 只构建可见项）
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bool themeMounted = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        builder: (context, child) => AvesMiuixTheme(
          enabled: true,
          child: Builder(
            builder: (context) {
              themeMounted = MiuixTheme.maybeOf(context) != null;
              return child ?? const SizedBox();
            },
          ),
        ),
        home: const MiuixSamplePage(),
      ),
    );
    // 手工推进几帧：Miuix 的弹簧动画不适合用 pumpAndSettle
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(themeMounted, true);
    // 顶栏标题、列表项、卡片与按钮都渲染出来了
    expect(find.text('Miuix 样张'), findsWidgets);
    expect(find.text('列表项 Preference'), findsOneWidget);
    expect(find.text('开关'), findsOneWidget);
    expect(find.byType(MiuixSwitch), findsWidgets);
    expect(find.text('MiuixCard'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });

  testWidgets('material skin leaves widget tree untouched', (tester) async {
    bool themeMounted = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        builder: (context, child) => AvesMiuixTheme(
          enabled: false,
          child: Builder(
            builder: (context) {
              themeMounted = MiuixTheme.maybeOf(context) != null;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(themeMounted, false);
  });
}
