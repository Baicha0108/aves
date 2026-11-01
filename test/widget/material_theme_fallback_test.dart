import 'package:aves/model/settings/settings.dart';
import 'package:aves/theme/colors.dart';
import 'package:aves/theme/themes.dart';
import 'package:aves/widgets/settings/language/locales.dart';
import 'package:aves_miuix/aves_miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../common.dart';

void main() {
  setUpAll(setUpAllServices);
  tearDownAll(tearDownAllServices);
  setUp(setUpServices);

  test('Material popup theme keeps upstream defaults when Miuix is disabled', () {
    settings.useMiuixUi = false;
    final theme = Themes.darkTheme(AvesColorsData.defaultAccent, true, KnownLocale.english);

    expect(theme.popupMenuTheme.surfaceTintColor, isNull);
  });

  test('Miuix dark snackbar uses the same surface palette as other Miuix overlays', () {
    settings.useMiuixUi = true;
    final theme = Themes.darkTheme(AvesColorsData.defaultAccent, true, KnownLocale.english);
    final miuixColors = avesMiuixColors(accent: theme.colorScheme.primary, dark: true);

    expect(theme.popupMenuTheme.surfaceTintColor, Colors.transparent);
    expect(theme.snackBarTheme.backgroundColor, miuixColors.surfaceContainerHigh);
    expect(theme.snackBarTheme.contentTextStyle?.color, miuixColors.onSurfaceContainer);
  });
}
