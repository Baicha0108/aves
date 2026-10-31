import 'package:aves/theme/text.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/widgets/common/basic/list_tiles/common.dart';
import 'package:aves_miuix/aves_miuix.dart';
import 'package:material_ui/material_ui.dart';

class const SettingsSubPageTile({
  super.key,
  required final TitleBuilder title,
  final WidgetBuilder? subtitle,
  required final String routeName,
  required final WidgetBuilder builder,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // baicha fork: Miuix skin → Miuix arrow preference row
    if (settings.useMiuixUi) {
      final theme = MiuixTheme.of(context);
      final subtitleBuilder = subtitle;
      return MiuixArrowPreference(
        title: title(context) ?? AText.valueNotAvailable,
        // the bottom slot is free-form (unlike `summary`): without an explicit style it
        // inherits the ambient colour, which reads as white on light themes
        bottomAction: subtitleBuilder == null
            ? null
            : DefaultTextStyle.merge(
                style: theme.textStyles.footnote1.copyWith(color: MiuixBasicComponentDefaults.summaryColor(context).color),
                child: subtitleBuilder(context),
              ),
        onClick: () {
          Navigator.maybeOf(context)?.push(
            MaterialPageRoute(
              settings: RouteSettings(name: routeName),
              builder: builder,
            ),
          );
        },
      );
    }

    return ListTile(
      title: Text(title(context) ?? AText.valueNotAvailable),
      subtitle: subtitle?.call(context),
      onTap: () {
        Navigator.maybeOf(context)?.push(
          MaterialPageRoute(
            settings: RouteSettings(name: routeName),
            builder: builder,
          ),
        );
      },
    );
  }
}
