import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/settings/defaults.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(setUpAllServices);
  tearDownAll(tearDownAllServices);

  test('TV layout stays disabled and its obsolete preference is removed', () async {
    await settings.store.setBool(SettingKeys.forceTvLayoutKey, true);
    settings.bottomNavigationActions = [];
    settings.showOverlayOnOpening = false;
    settings.mustBackTwiceToExit = false;

    expect(settings.forceTvLayout, isFalse);
    expect(settings.useTvLayout, isFalse);

    settings.forceTvLayout = true;
    expect(settings.store.get(SettingKeys.forceTvLayoutKey), isNull);

    await settings.store.setBool(SettingKeys.forceTvLayoutKey, true);
    await settings.sanitize();

    expect(settings.store.get(SettingKeys.forceTvLayoutKey), isNull);
    expect(settings.bottomNavigationActions, SettingsDefaults.bottomNavigationActions);
    expect(settings.showOverlayOnOpening, isTrue);
    // Only the two settings known to make the phone UI appear broken are migrated.
    expect(settings.mustBackTwiceToExit, isFalse);
    expect(settings.useTvLayout, isFalse);
  });
}
