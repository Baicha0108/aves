import 'package:aves/model/settings/settings.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(setUpAllServices);
  tearDownAll(tearDownAllServices);

  test('TV layout stays disabled and its obsolete preference is removed', () async {
    await settings.store.setBool(SettingKeys.forceTvLayoutKey, true);

    expect(settings.forceTvLayout, isFalse);
    expect(settings.useTvLayout, isFalse);

    settings.forceTvLayout = true;
    expect(settings.store.get(SettingKeys.forceTvLayoutKey), isNull);

    await settings.store.setBool(SettingKeys.forceTvLayoutKey, true);
    await settings.sanitize();

    expect(settings.store.get(SettingKeys.forceTvLayoutKey), isNull);
    expect(settings.useTvLayout, isFalse);
  });
}
