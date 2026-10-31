import 'package:aves/model/settings/defaults.dart';
import 'package:aves_model/aves_model.dart';

mixin DisplaySettings on SettingsAccess {
  DisplayRefreshRateMode get displayRefreshRateMode => getEnumOrDefault(SettingKeys.displayRefreshRateModeKey, SettingsDefaults.displayRefreshRateMode, DisplayRefreshRateMode.values);

  set displayRefreshRateMode(DisplayRefreshRateMode newValue) => set(SettingKeys.displayRefreshRateModeKey, newValue.name);

  AvesThemeBrightness get themeBrightness => getEnumOrDefault(SettingKeys.themeBrightnessKey, SettingsDefaults.themeBrightness, AvesThemeBrightness.values);

  set themeBrightness(AvesThemeBrightness newValue) => set(SettingKeys.themeBrightnessKey, newValue.name);

  AvesThemeColorMode get themeColorMode => getEnumOrDefault(SettingKeys.themeColorModeKey, SettingsDefaults.themeColorMode, AvesThemeColorMode.values);

  set themeColorMode(AvesThemeColorMode newValue) => set(SettingKeys.themeColorModeKey, newValue.name);

  bool get enableDynamicColor => getBool(SettingKeys.enableDynamicColorKey) ?? SettingsDefaults.enableDynamicColor;

  set enableDynamicColor(bool newValue) => set(SettingKeys.enableDynamicColorKey, newValue);

  bool get enableBlurEffect => getBool(SettingKeys.enableBlurEffectKey) ?? SettingsDefaults.enableBlurEffect;

  set enableBlurEffect(bool newValue) => set(SettingKeys.enableBlurEffectKey, newValue);

  bool get useMiuixUi => getBool(SettingKeys.useMiuixUiKey) ?? SettingsDefaults.useMiuixUi;

  set useMiuixUi(bool newValue) => set(SettingKeys.useMiuixUiKey, newValue);

  MaxBrightness get maxBrightness => getEnumOrDefault(SettingKeys.maxBrightnessKey, SettingsDefaults.maxBrightness, MaxBrightness.values);

  set maxBrightness(MaxBrightness newValue) => set(SettingKeys.maxBrightnessKey, newValue.name);

  // Aves Miuix intentionally ships the phone/tablet UI only.
  //
  // Keep these accessors because the upstream UI contains many `useTvLayout`
  // branches. Returning constants disables every one of them consistently,
  // including values restored from an old settings backup.
  bool get forceTvLayout => false;

  set forceTvLayout(bool newValue) => set(SettingKeys.forceTvLayoutKey, null);

  bool get useTvLayout => false;

  bool get isReadOnly => useTvLayout;
}
