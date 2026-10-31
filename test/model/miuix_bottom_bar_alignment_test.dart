import 'package:aves/model/settings/enums/miuix_bottom_bar_alignment.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(setUpAllServices);
  tearDownAll(tearDownAllServices);

  setUp(setUpServices);

  test('Miuix bottom bar alignment defaults to center and persists valid values', () {
    expect(settings.miuixBottomBarAlignment, MiuixBottomBarAlignment.center);

    settings.miuixBottomBarAlignment = MiuixBottomBarAlignment.left;
    expect(settings.miuixBottomBarAlignment, MiuixBottomBarAlignment.left);

    settings.miuixBottomBarAlignment = MiuixBottomBarAlignment.right;
    expect(settings.miuixBottomBarAlignment, MiuixBottomBarAlignment.right);
  });

  test('unknown Miuix bottom bar alignment falls back to center', () async {
    await settings.store.setString(SettingKeys.miuixBottomBarAlignmentKey, 'unsupported');
    expect(settings.miuixBottomBarAlignment, MiuixBottomBarAlignment.center);
  });
}
