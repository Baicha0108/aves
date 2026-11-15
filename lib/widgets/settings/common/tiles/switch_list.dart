import 'dart:async';

import 'package:aves/model/settings/settings.dart';
import 'package:aves/theme/durations.dart';
import 'package:aves/theme/text.dart';
import 'package:aves/widgets/common/basic/list_tiles/common.dart';
import 'package:aves_miuix/aves_miuix.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class const SettingsSwitchListTile({
  super.key,
  required final bool Function(BuildContext, Settings) selector,
  required final FutureOr<void> Function(bool value)? onChanged,
  final Widget? leading,
  required final TitleBuilder title,
  final TitleBuilder? subtitle,
  final Widget? trailing,
}) extends StatefulWidget {
  static const disabledOpacity = .2;

  @override
  State<SettingsSwitchListTile> createState() => _SettingsSwitchListTileState();
}

class _SettingsSwitchListTileState extends State<SettingsSwitchListTile> {
  @override
  Widget build(BuildContext context) {
    return Selector<Settings, bool>(
      selector: widget.selector,
      builder: (context, current, child) {
        Widget? leading = widget.leading;
        final subtitle = widget.subtitle?.call(context);
        final trailing = widget.trailing;
        final onChanged = widget.onChanged;

        if (leading != null) {
          leading = AnimatedOpacity(
            opacity: current && onChanged != null ? 1 : SettingsSwitchListTile.disabledOpacity,
            duration: ADurations.toggleableTransitionLoose,
            child: leading,
          );
        }

        return MiuixSwitchPreference(
          value: current,
          title: widget.title(context) ?? AText.valueNotAvailable,
          summary: subtitle,
          startAction: leading,
          endActions: trailing != null ? [trailing] : null,
          enabled: onChanged != null,
          onChanged: (v) async {
            await onChanged?.call(v);
            // update in case other props (e.g. subtitle) changed as a consequence
            setState(() {});
          },
        );
      },
    );
  }
}
