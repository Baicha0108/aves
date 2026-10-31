import 'package:aves/model/settings/settings.dart';
import 'package:aves/widgets/miuix/miuix_sample_page.dart';
import 'package:aves_miuix/aves_miuix.dart';
import 'package:material_ui/material_ui.dart';

/// 关于页里的 Miuix 入口。
///
/// P0 阶段用来从原生界面跳到 Miuix 组件样张页；同时它本身就是一个
/// "Miuix 组件放进 aves 原生页面" 的最小示例。
class MiuixSkinEntry extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    if (!settings.useMiuixUi) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: MiuixCard(
        child: MiuixBasicComponent(
          title: 'Miuix 组件样张',
          summary: 'HyperOS 风格组件预览与验证',
          insideMargin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          endActions: const [MiuixIcon(icon: Icons.chevron_right)],
          onClick: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const MiuixSamplePage()),
          ),
        ),
      ),
    );
  }
}
