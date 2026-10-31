import 'package:aves_miuix/aves_miuix.dart';
import 'package:material_ui/material_ui.dart';

/// Miuix 组件样张页。
///
/// P0 验证用页面：在真机上确认 Miuix 移植库在 aves 里能否正常渲染
/// （超椭圆圆角、弹簧动效、Monet 取色、弹层与输入控件），
/// 不依赖 aves 自身界面的任何改造。
class MiuixSamplePage extends StatefulWidget {
  static const routeName = '/miuix-sample';

  const new({super.key});

  @override
  State<MiuixSamplePage> createState() => _MiuixSamplePageState();
}

class _MiuixSamplePageState extends State<MiuixSamplePage> {
  final MiuixSnackbarHostState _snackbarHost = MiuixSnackbarHostState();
  final TextEditingController _textController = TextEditingController();

  bool _switchValue = true;
  bool _checkboxValue = true;
  int _radioIndex = 0;
  double _sliderValue = 0.4;
  int _tabIndex = 1;
  bool _showDialog = false;
  bool _showBottomSheet = false;

  static const _itemMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
  static const _tabs = ['相册', '标签', '位置'];
  static const _radioLabels = ['关闭', '开启', '自动'];

  @override
  void dispose() {
    _textController.dispose();
    _snackbarHost.dispose();
    super.dispose();
  }

  void _showMessage(String message) => _snackbarHost.showSnackbar(message);

  @override
  Widget build(BuildContext context) {
    final theme = MiuixTheme.of(context);
    final ts = theme.textStyles;
    final colors = theme.colors;

    return MiuixScaffold(
      topBar: MiuixTopAppBar(
        title: 'Miuix 样张',
        subtitle: 'aves × HyperOS',
        navigationIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: MiuixIconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Icon(Icons.arrow_back),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: MiuixIconButton(
                onPressed: () => _showMessage('这是一条 Miuix Snackbar'),
                child: const Icon(Icons.notifications_none),
              ),
            ),
          ),
        ],
      ),
      snackbarHost: MiuixSnackbarHost(state: _snackbarHost),
      content: (padding) => Material(
        // MiuixTextField 内部使用 Flutter TextField，需要 Material 祖先
        type: MaterialType.transparency,
        child: Stack(
          children: [
            ListView(
              padding: padding.copyWith(bottom: 40),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                  child: MiuixTabRow(
                    tabs: _tabs,
                    selectedTabIndex: _tabIndex,
                    onTabSelected: (index) => setState(() => _tabIndex = index),
                  ),
                ),
                const MiuixSmallTitle('列表项 Preference'),
                _GroupCard(
                  children: [
                    MiuixBasicComponent(
                      title: '开关',
                      summary: 'MiuixSwitch / 整行可点',
                      insideMargin: _itemMargin,
                      endActions: [
                        MiuixSwitch(
                          value: _switchValue,
                          onChanged: (value) => setState(() => _switchValue = value),
                        ),
                      ],
                      onClick: () => setState(() => _switchValue = !_switchValue),
                    ),
                    const _IndentDivider(),
                    MiuixBasicComponent(
                      title: '复选',
                      summary: 'MiuixCheckbox',
                      insideMargin: _itemMargin,
                      endActions: [
                        MiuixCheckbox(
                          value: _checkboxValue,
                          onChanged: (value) => setState(() => _checkboxValue = value ?? false),
                        ),
                      ],
                      onClick: () => setState(() => _checkboxValue = !_checkboxValue),
                    ),
                    const _IndentDivider(),
                    MiuixBasicComponent(
                      title: '单选',
                      summary: 'MiuixRadioButton · 当前 ${_radioLabels[_radioIndex]}',
                      insideMargin: _itemMargin,
                      endActions: [
                        MiuixRadioButton(
                          selected: _radioIndex == 1,
                          onChanged: (_) => setState(() => _radioIndex = 1),
                        ),
                      ],
                      onClick: () => setState(() => _radioIndex = (_radioIndex + 1) % _radioLabels.length),
                    ),
                    const _IndentDivider(),
                    MiuixBasicComponent(
                      title: '徽标与图标',
                      summary: 'MiuixBadge / MiuixIcon',
                      insideMargin: _itemMargin,
                      startAction: const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: MiuixIcon(icon: Icons.image_outlined),
                      ),
                      endActions: const [MiuixBadge(child: Text('新'))],
                      onClick: () => _showMessage('点击了列表项'),
                    ),
                    const _IndentDivider(),
                    const MiuixBasicComponent(
                      title: '禁用项',
                      summary: 'enabled = false',
                      insideMargin: _itemMargin,
                      enabled: false,
                    ),
                  ],
                ),
                const MiuixSmallTitle('输入 Input'),
                _GroupCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: MiuixTextField(
                        controller: _textController,
                        label: '搜索相册',
                        useLabelAsPlaceholder: true,
                        leadingIcon: const Icon(Icons.search, size: 20),
                        trailingIcon: const Icon(Icons.close, size: 20),
                        singleLine: true,
                      ),
                    ),
                    const _IndentDivider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MiuixText('滑块 ${(_sliderValue * 100).round()}%', style: ts.body2),
                          const SizedBox(height: 4),
                          MiuixSlider(
                            value: _sliderValue,
                            onValueChanged: (value) => setState(() => _sliderValue = value),
                            showKeyPoints: true,
                            keyPoints: const [0, 0.25, 0.5, 0.75, 1],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const MiuixSmallTitle('卡片与按钮'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: MiuixCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MiuixText('MiuixCard', style: ts.title4),
                          const SizedBox(height: 6),
                          MiuixText(
                            '超椭圆圆角（squircle）、分组卡片、按压反馈、进度条都来自 Miuix 移植库。',
                            style: ts.body2,
                            color: colors.onSurfaceVariantSummary,
                          ),
                          const SizedBox(height: 16),
                          MiuixLinearProgressIndicator(progress: _sliderValue),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: MiuixButton(
                                  onPressed: () => _showMessage('确认'),
                                  child: MiuixText('确认', style: ts.button),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: MiuixTextButton('取消', onPressed: () => _showMessage('取消')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const MiuixSmallTitle('浮层 Overlays'),
                _GroupCard(
                  children: [
                    MiuixBasicComponent(
                      title: '对话框',
                      summary: 'MiuixOverlayDialog',
                      insideMargin: _itemMargin,
                      endActions: const [MiuixIcon(icon: Icons.chevron_right)],
                      onClick: () => setState(() => _showDialog = true),
                    ),
                    const _IndentDivider(),
                    MiuixBasicComponent(
                      title: '底部弹层',
                      summary: 'MiuixOverlayBottomSheet',
                      insideMargin: _itemMargin,
                      endActions: const [MiuixIcon(icon: Icons.chevron_right)],
                      onClick: () => setState(() => _showBottomSheet = true),
                    ),
                  ],
                ),
              ],
            ),
            MiuixOverlayDialog(
              show: _showDialog,
              title: 'Miuix 对话框',
              summary: '从屏幕中浮起，圆角与遮罩按 Miuix 规范。',
              onDismissRequest: () => setState(() => _showDialog = false),
              content: Align(
                alignment: Alignment.centerRight,
                child: MiuixTextButton('知道了', onPressed: () => setState(() => _showDialog = false)),
              ),
            ),
            MiuixOverlayBottomSheet(
              show: _showBottomSheet,
              title: '底部弹层',
              onDismissRequest: () => setState(() => _showBottomSheet = false),
              content: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MiuixText('底部弹层带拖拽手柄，可下拉关闭。', style: ts.body1),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: MiuixTextButton('关闭', onPressed: () => setState(() => _showBottomSheet = false)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分组卡片：圆角卡片 + 可选的分隔线。
class _GroupCard extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: MiuixCard(child: Column(children: children)),
  );
}

/// 左侧缩进的分隔线，用于卡片内的条目之间。
class _IndentDivider extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(left: 16),
    child: MiuixHorizontalDivider(),
  );
}
