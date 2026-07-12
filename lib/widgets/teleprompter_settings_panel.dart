import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../providers/connection_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/teleprompter_provider.dart';
import '../services/font_service.dart';
import '../theme/app_colors.dart';

/// 提词器设置面板（抽屉形式）
///
/// 从右侧滑入，覆盖在提词器界面之上。
/// 按播放与进度、正文外观、排版、阅读区域分组。
class TeleprompterSettingsPanel extends StatefulWidget {
  final VoidCallback onClose;

  const TeleprompterSettingsPanel({super.key, required this.onClose});

  @override
  State<TeleprompterSettingsPanel> createState() =>
      _TeleprompterSettingsPanelState();
}

class _TeleprompterSettingsPanelState extends State<TeleprompterSettingsPanel> {
  late final TextEditingController _scrollSpeedController;
  late final TextEditingController _bodyFontSizeController;
  late final FocusNode _scrollSpeedFocusNode;
  late final FocusNode _bodyFontSizeFocusNode;

  @override
  void initState() {
    super.initState();
    _scrollSpeedController = TextEditingController();
    _bodyFontSizeController = TextEditingController();
    _scrollSpeedFocusNode = FocusNode();
    _bodyFontSizeFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _scrollSpeedController.dispose();
    _bodyFontSizeController.dispose();
    _scrollSpeedFocusNode.dispose();
    _bodyFontSizeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final panelWidth = MediaQuery.sizeOf(context).width < 340
        ? MediaQuery.sizeOf(context).width
        : 340.0;

    return GestureDetector(
      onTap: () {},
      child: Material(
        color: AppColors.surface,
        child: SizedBox(
          width: panelWidth,
          child: Consumer<SettingsProvider>(
            builder: (context, provider, _) {
              final settings = provider.mergedSettings;
              final isRemoteClient = context
                  .watch<ConnectionProvider>()
                  .isRemote;
              final isPlaying = context.watch<TeleprompterProvider>().isPlaying;
              return Column(
                children: [
                  _buildTitleBar(context),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // ── 1. 播放与进度 ──
                        _buildSectionTitle(context, '播放与进度'),
                        const SizedBox(height: 8),
                        if (!isRemoteClient)
                          _buildScrollSpeedInput(context, provider, settings),
                        _buildProgressDisplayItems(context, provider, settings),
                        _buildProgressFontSizeSlider(
                          context,
                          provider,
                          settings,
                        ),
                        const Divider(height: 24),

                        // ── 2. 正文外观 ──
                        _buildSectionTitle(context, '正文外观'),
                        const SizedBox(height: 8),
                        _buildTeleprompterFontTile(context, provider, settings),
                        _buildBodyFontSizeInput(context, provider, settings),
                        _buildTeleprompterBgColorTile(
                          context,
                          provider,
                          settings,
                        ),
                        _buildMirrorTextSwitch(context, provider, settings),
                        _buildExtraBoldSlider(context, provider, settings),
                        const SizedBox(height: 4),
                        _buildEmphasisSection(context, provider, settings),
                        const Divider(height: 24),

                        // ── 3. 排版 ──
                        _buildSectionTitle(context, '排版'),
                        const SizedBox(height: 8),
                        _buildLetterSpacingSlider(
                          context,
                          provider,
                          settings,
                          enabled: !isPlaying,
                        ),
                        _buildLineHeightSlider(
                          context,
                          provider,
                          settings,
                          enabled: !isPlaying,
                        ),
                        if (isPlaying)
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 4),
                            child: Text(
                              '播放中已锁定字间距和行距，暂停后可调整',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        _buildTextPaddingSlider(context, provider, settings),
                        const Divider(height: 24),

                        // ── 4. 阅读区域框设置 ──
                        _buildSectionTitle(context, '阅读区域框'),
                        const SizedBox(height: 8),
                        _buildReadingAreaPositionSlider(
                          context,
                          provider,
                          settings,
                        ),
                        _buildReadingAreaBorderSlider(
                          context,
                          provider,
                          settings,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          const Text(
            '提词器设置',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: AppColors.textSecondary,
            onPressed: widget.onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final primary = Theme.of(context).colorScheme.primary;
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: 0.5,
      ),
    );
  }

  // ─── 播放与进度 ────────────────────────────────────────

  /// 字号（占正文比例）
  Widget _buildProgressFontSizeSlider(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    return _buildSlider(
      context,
      icon: Icons.text_fields,
      title: '字号比例',
      value: settings.progressInfoSizeRatio,
      min: 0.3,
      max: 1.0,
      divisions: 70,
      displayFormatter: (v) => '${(v * 100).round()}%',
      onChanged: (v) => provider.setProgressInfoSizeRatio(v),
      onReset: () => provider.setProgressInfoSizeRatio(0.6),
    );
  }

  Widget _buildScrollSpeedInput(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    _syncTextController(
      _scrollSpeedController,
      _scrollSpeedFocusNode,
      '${settings.wpm}',
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.speed, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          const SizedBox(
            width: 72,
            child: Text(
              '滚动速度',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _scrollSpeedController,
              focusNode: _scrollSpeedFocusNode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                suffixText: '字/分',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              onSubmitted: (value) {
                final parsed = int.tryParse(value.trim());
                if (parsed != null) provider.setWpm(parsed < 0 ? 0 : parsed);
              },
            ),
          ),
          IconButton(
            tooltip: '应用速度',
            icon: const Icon(Icons.check, size: 18),
            onPressed: () {
              final parsed = int.tryParse(_scrollSpeedController.text.trim());
              if (parsed != null) provider.setWpm(parsed < 0 ? 0 : parsed);
            },
          ),
        ],
      ),
    );
  }

  /// 显示项切换（用时/百分比/速度/时间）
  Widget _buildProgressDisplayItems(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    return Column(
      children: [
        _buildProgressToggleItem(
          icon: Icons.schedule,
          title: '已用时间',
          value: settings.progressShowTime,
          onChanged: (_) => provider.toggleProgressShowTime(),
        ),
        _buildProgressToggleItem(
          icon: Icons.percent,
          title: '进度百分比',
          value: settings.progressShowPercentage,
          onChanged: (_) => provider.toggleProgressShowPercentage(),
        ),
        _buildProgressToggleItem(
          icon: Icons.speed,
          title: '滚动速度',
          value: settings.progressShowSpeed,
          onChanged: (_) => provider.toggleProgressShowSpeed(),
        ),
        _buildProgressToggleItem(
          icon: Icons.access_time,
          title: '当前时间',
          value: settings.progressShowCurrentTime,
          onChanged: (_) => provider.toggleProgressShowCurrentTime(),
        ),
      ],
    );
  }

  Widget _buildProgressToggleItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            height: 28,
            child: Transform.scale(
              scale: 0.8,
              child: Switch(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 正文外观与排版 ────────────────────────────────────

  /// 提词器正文字体选择
  Widget _buildTeleprompterFontTile(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    final fontService = FontService();

    return _buildValueItem(
      leading: const Icon(
        Icons.font_download,
        size: 18,
        color: AppColors.textSecondary,
      ),
      title: '正文字体',
      value: settings.teleprompterFontFamily,
      onTap: () {
        List<String> allFonts = [];
        List<String> filteredFonts = [];

        showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (context, dialogSetState) {
              if (allFonts.isEmpty) {
                fontService.getAvailableFonts().then((fonts) {
                  if (!context.mounted) return;
                  dialogSetState(() {
                    allFonts = fonts;
                    filteredFonts = fonts;
                  });
                });
              }

              return AlertDialog(
                title: Text('选择正文字体 (${allFonts.length}个)'),
                contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                content: SizedBox(
                  width: 300,
                  height: 350,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: '搜索字体...',
                            prefixIcon: Icon(Icons.search, size: 20),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            fontService.searchFonts(value).then((fonts) {
                              if (!context.mounted) return;
                              dialogSetState(() => filteredFonts = fonts);
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filteredFonts.isEmpty
                            ? const Center(child: Text('没有匹配的字体'))
                            : ListView.builder(
                                itemCount: filteredFonts.length,
                                itemBuilder: (context, index) {
                                  final f = filteredFonts[index];
                                  final isSelected =
                                      f == settings.teleprompterFontFamily;
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      f,
                                      style: TextStyle(
                                        fontFamily: f,
                                        fontSize: 13,
                                        color: isSelected
                                            ? AppColors.primary
                                            : null,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 18,
                                            color: AppColors.primary,
                                          )
                                        : null,
                                    onTap: () {
                                      provider.setTeleprompterFontFamily(f);
                                      Navigator.pop(ctx);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('关闭'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLetterSpacingSlider(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings, {
    bool enabled = true,
  }) {
    return _buildSlider(
      context,
      icon: Icons.space_bar,
      title: '字间距',
      value: settings.letterSpacing,
      min: -2,
      max: 10,
      divisions: 12,
      displayFormatter: (v) => '${v.toStringAsFixed(1)}px',
      onChanged: enabled ? (v) => provider.setLetterSpacing(v) : null,
      onReset: enabled ? () => provider.setLetterSpacing(0) : null,
    );
  }

  Widget _buildTeleprompterBgColorTile(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    final color = Color(settings.teleprompterBgColor);
    return _buildValueItem(
      leading: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColors.border),
        ),
      ),
      title: '背景色',
      value: _formatHex(color),
      onTap: () => _showColorPicker(
        context,
        currentColor: color,
        onColorSelected: (selected) =>
            provider.setTeleprompterBgColor(selected.toARGB32()),
      ),
    );
  }

  Widget _buildValueItem({
    required Widget leading,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 18, height: 18, child: Center(child: leading)),
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyFontSizeInput(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    _syncTextController(
      _bodyFontSizeController,
      _bodyFontSizeFocusNode,
      settings.fontSize.toStringAsFixed(
        settings.fontSize.truncateToDouble() == settings.fontSize ? 0 : 1,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.format_size,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          const SizedBox(
            width: 72,
            child: Text(
              '正文字号',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _bodyFontSizeController,
              focusNode: _bodyFontSizeFocusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                suffixText: 'px',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              onSubmitted: (value) {
                final parsed = double.tryParse(value.trim());
                if (parsed != null && parsed > 0) {
                  provider.setFontSize(parsed);
                }
              },
            ),
          ),
          IconButton(
            tooltip: '应用字号',
            icon: const Icon(Icons.check, size: 18),
            onPressed: () {
              final parsed = double.tryParse(
                _bodyFontSizeController.text.trim(),
              );
              if (parsed != null && parsed > 0) {
                provider.setFontSize(parsed);
              }
            },
          ),
          IconButton(
            tooltip: '重置字号',
            icon: const Icon(Icons.restart_alt, size: 18),
            onPressed: () => provider.setFontSize(64),
          ),
        ],
      ),
    );
  }

  Widget _buildLineHeightSlider(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings, {
    bool enabled = true,
  }) {
    return _buildSlider(
      context,
      icon: Icons.format_line_spacing,
      title: '行距',
      value: settings.lineHeight,
      min: 1.0,
      max: 2.5,
      divisions: 15,
      displayFormatter: (v) => '${v.toStringAsFixed(1)}x',
      onChanged: enabled
          ? (v) => provider.setLineHeight(double.parse(v.toStringAsFixed(1)))
          : null,
      onReset: enabled ? () => provider.setLineHeight(1.5) : null,
    );
  }

  Widget _buildMirrorTextSwitch(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    return SwitchListTile(
      dense: true,
      secondary: const Icon(Icons.flip, size: 20),
      title: const Text('镜像提词画面', style: TextStyle(fontSize: 14)),
      subtitle: const Text(
        '水平翻转正文、阅读框和进度条，适配分光镜',
        style: TextStyle(fontSize: 12),
      ),
      value: settings.mirrorMode,
      onChanged: (_) => provider.toggleMirrorMode(),
    );
  }

  /// 额外加粗字重
  Widget _buildExtraBoldSlider(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    return SwitchListTile(
      dense: true,
      secondary: const Icon(Icons.format_bold, size: 20),
      title: const Text('默认加粗', style: TextStyle(fontSize: 14)),
      value: settings.defaultBold,
      onChanged: (_) => provider.toggleDefaultBold(),
    );
  }

  /// 强调效果
  Widget _buildEmphasisSection(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, top: 4, bottom: 4),
          child: Text(
            '强调效果',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        // 已读字变淡（默认开）
        SwitchListTile(
          dense: true,
          secondary: const Icon(Icons.opacity, size: 20),
          title: const Text('已读字变淡', style: TextStyle(fontSize: 14)),
          subtitle: const Text(
            '已读过的字符变为半透明（默认开）',
            style: TextStyle(fontSize: 12),
          ),
          value: settings.grayReadChars,
          onChanged: (_) => provider.toggleGrayReadChars(),
        ),
        // 当前字加粗（默认关）
        SwitchListTile(
          dense: true,
          secondary: const Icon(Icons.format_bold, size: 20),
          title: const Text('当前字加粗', style: TextStyle(fontSize: 14)),
          value: settings.highlightCurrentChar,
          onChanged: (_) => provider.toggleHighlightCurrentChar(),
        ),
        // 当前字加下划线（默认关）
        SwitchListTile(
          dense: true,
          secondary: const Icon(Icons.format_underlined, size: 20),
          title: const Text('当前字加下划线', style: TextStyle(fontSize: 14)),
          value: settings.underlineCurrentChar,
          onChanged: (_) => provider.toggleUnderlineCurrentChar(),
        ),
      ],
    );
  }

  // ─── 阅读区域 ──────────────────────────────────────────

  /// 边框粗细
  Widget _buildReadingAreaBorderSlider(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    return _buildSlider(
      context,
      icon: Icons.crop_square,
      title: '边框粗细',
      value: settings.readingAreaBorderWidth,
      min: 0,
      max: 8,
      divisions: 16,
      displayFormatter: (v) => '${v.toStringAsFixed(1)}px',
      onChanged: (v) => provider.setReadingAreaBorderWidth(v),
      onReset: () => provider.setReadingAreaBorderWidth(3.0),
    );
  }

  /// 屏幕位置
  Widget _buildReadingAreaPositionSlider(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    return _buildSlider(
      context,
      icon: Icons.vertical_align_center,
      title: '屏幕位置',
      value: settings.readingLineOffset,
      min: 0.1,
      max: 0.9,
      divisions: 80,
      displayFormatter: (v) => '${(v * 100).round()}%',
      onChanged: (v) => provider.setReadingLineOffset(v),
      onReset: () => provider.setReadingLineOffset(0.5),
    );
  }

  Widget _buildTextPaddingSlider(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    return _buildSlider(
      context,
      icon: Icons.format_indent_increase,
      title: '正文边距',
      value: settings.paddingX,
      min: 0,
      max: 40,
      divisions: 40,
      displayFormatter: (v) => '${v.round()}%',
      onChanged: (v) => provider.setPaddingX(v),
      onReset: () => provider.setPaddingX(5.0),
    );
  }

  // ─── 通用控件 ──────────────────────────────────────────

  Widget _buildSlider(
    BuildContext context, {
    IconData? icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double>? onChanged,
    String Function(double)? displayFormatter,
    VoidCallback? onReset,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final display = displayFormatter != null
        ? displayFormatter(value)
        : '${value.round()}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 72,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              display,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onReset != null)
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                icon: const Icon(Icons.restart_alt, size: 16),
                padding: EdgeInsets.zero,
                color: AppColors.textMuted,
                onPressed: onReset,
                tooltip: '重置',
              ),
            ),
        ],
      ),
    );
  }

  void _showColorPicker(
    BuildContext context, {
    required Color currentColor,
    required ValueChanged<Color> onColorSelected,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _TeleprompterColorPickerDialog(
        currentColor: currentColor,
        onColorSelected: onColorSelected,
      ),
    );
  }

  String _formatHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  void _syncTextController(
    TextEditingController controller,
    FocusNode focusNode,
    String text,
  ) {
    if (focusNode.hasFocus || controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _TeleprompterColorPickerDialog extends StatefulWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorSelected;

  const _TeleprompterColorPickerDialog({
    required this.currentColor,
    required this.onColorSelected,
  });

  @override
  State<_TeleprompterColorPickerDialog> createState() =>
      _TeleprompterColorPickerDialogState();
}

class _TeleprompterColorPickerDialogState
    extends State<_TeleprompterColorPickerDialog> {
  late Color _pickerColor;
  late final TextEditingController _hexController;
  String? _hexError;

  @override
  void initState() {
    super.initState();
    _pickerColor = widget.currentColor;
    _hexController = TextEditingController(text: _formatHex(_pickerColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择背景色'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorPicker(
              pickerColor: _pickerColor,
              onColorChanged: (color) => setState(() {
                _pickerColor = color;
                _hexError = null;
                _syncHex(color);
              }),
              enableAlpha: true,
              displayThumbColor: true,
              pickerAreaHeightPercent: 0.8,
              portraitOnly: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hexController,
              decoration: InputDecoration(
                labelText: 'HEX',
                hintText: '#AARRGGBB 或 #RRGGBB',
                errorText: _hexError,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F#]')),
              ],
              maxLength: 9,
              onChanged: (value) {
                final parsed = _parseHex(value);
                setState(() {
                  _hexError = parsed == null ? '请输入 6 或 8 位十六进制颜色' : null;
                  if (parsed != null) _pickerColor = parsed;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            widget.onColorSelected(const Color(0xFF000000));
            Navigator.pop(context);
          },
          child: const Text('恢复黑色'),
        ),
        FilledButton(
          onPressed: () {
            widget.onColorSelected(_pickerColor);
            Navigator.pop(context);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }

  Color? _parseHex(String value) {
    final normalized = value.trim().replaceFirst('#', '');
    if (normalized.length != 6 && normalized.length != 8) return null;
    final argb = normalized.length == 6 ? 'FF$normalized' : normalized;
    final parsed = int.tryParse(argb, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  void _syncHex(Color color) {
    final text = _formatHex(color);
    _hexController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  String _formatHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
}
