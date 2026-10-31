import 'dart:async';

import 'package:aves/model/device.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/theme/colors.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/view/view.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/settings/common/tile_leading.dart';
import 'package:aves/widgets/settings/common/tiles/single_selection.dart';
import 'package:aves/widgets/settings/common/tiles/switch_list.dart';
import 'package:aves/widgets/settings/settings_definition.dart';
import 'package:aves_model/aves_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class DisplaySection extends SettingsSection {
  @override
  String get key => 'display';

  @override
  Widget icon(BuildContext context) => SettingsTileLeading(
    icon: AIcons.display,
    color: context.select<AvesColorsData, Color>((v) => v.display),
  );

  @override
  String title(BuildContext context) => context.l10n.settingsDisplaySectionTitle;

  @override
  Future<List<SettingsTile>> tiles(BuildContext context) => Future.value([
    if (!settings.useTvLayout) SettingsTileDisplayThemeBrightness(),
    SettingsTileDisplayThemeColorMode(),
    SettingsTileDisplayUiSkin(),
    if (device.isDynamicColorAvailable) SettingsTileDisplayEnableDynamicColor(),
    SettingsTileDisplayEnableBlurEffect(),
    if (!settings.useTvLayout) SettingsTileDisplayMaxBrightness(),
    if (!settings.useTvLayout) SettingsTileDisplayRefreshRateMode(),
  ]);
}

class SettingsTileDisplayThemeBrightness extends SettingsTile {
  @override
  List<String> get settingKeys => [SettingKeys.themeBrightnessKey];

  @override
  String title(BuildContext context) => context.l10n.settingsThemeBrightnessTile;

  @override
  Widget build(BuildContext context) => SettingsSelectionListTile<AvesThemeBrightness>(
    values: AvesThemeBrightness.values,
    getName: (context, v) => v.getName(context),
    selector: (context, s) => s.themeBrightness,
    onSelection: (v) => settings.themeBrightness = v,
    tileTitle: title,
    dialogTitle: context.l10n.settingsThemeBrightnessDialogTitle,
  );
}

class SettingsTileDisplayThemeColorMode extends SettingsTile {
  @override
  List<String> get settingKeys => [SettingKeys.themeColorModeKey];

  @override
  String title(BuildContext context) => context.l10n.settingsThemeColorHighlights;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => s.themeColorMode == AvesThemeColorMode.polychrome,
    onChanged: (v) => settings.themeColorMode = v ? AvesThemeColorMode.polychrome : AvesThemeColorMode.monochrome,
    title: title,
  );
}

class SettingsTileDisplayUiSkin extends SettingsTile {
  @override
  List<String> get settingKeys => [SettingKeys.useMiuixUiKey];

  @override
  String title(BuildContext context) => context.l10n.settingsMiuixUiTile;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => s.useMiuixUi,
    onChanged: (v) => settings.useMiuixUi = v,
    title: title,
  );
}

class SettingsTileDisplayEnableDynamicColor extends SettingsTile {
  @override
  List<String> get settingKeys => [SettingKeys.enableDynamicColorKey];

  @override
  String title(BuildContext context) => context.l10n.settingsThemeEnableDynamicColor;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => s.enableDynamicColor,
    onChanged: (v) => settings.enableDynamicColor = v,
    title: title,
  );
}

class SettingsTileDisplayEnableBlurEffect extends SettingsTile {
  @override
  List<String> get settingKeys => [SettingKeys.enableBlurEffectKey];

  @override
  String title(BuildContext context) => context.l10n.settingsViewerEnableOverlayBlurEffect;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => s.enableBlurEffect,
    onChanged: (v) => settings.enableBlurEffect = v,
    title: title,
  );
}

class SettingsTileDisplayMaxBrightness extends SettingsTile {
  @override
  List<String> get settingKeys => [SettingKeys.maxBrightnessKey];

  @override
  String title(BuildContext context) => context.l10n.settingsViewerMaximumBrightness;

  @override
  Widget build(BuildContext context) => SettingsSelectionListTile<MaxBrightness>(
    values: MaxBrightness.values,
    getName: (context, v) => v.getName(context),
    selector: (context, s) => s.maxBrightness,
    onSelection: (v) => settings.maxBrightness = v,
    tileTitle: title,
  );
}

class SettingsTileDisplayRefreshRateMode extends SettingsTile {
  @override
  List<String> get settingKeys => [SettingKeys.displayRefreshRateModeKey];

  @override
  String title(BuildContext context) => context.l10n.settingsDisplayRefreshRateModeTile;

  @override
  Widget build(BuildContext context) => SettingsSelectionListTile<DisplayRefreshRateMode>(
    values: DisplayRefreshRateMode.values,
    getName: (context, v) => v.getName(context),
    selector: (context, s) => s.displayRefreshRateMode,
    onSelection: (v) => settings.displayRefreshRateMode = v,
    tileTitle: title,
    dialogTitle: context.l10n.settingsDisplayRefreshRateModeDialogTitle,
  );
}
