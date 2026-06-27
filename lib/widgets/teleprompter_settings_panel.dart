import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../providers/connection_provider.dart';
import '../providers/settings_provider.dart';
import '../services/font_service.dart';
import '../theme/app_colors.dart';

/// 提词器设置面板（抽屉形式）
///
/// 从右侧滑入，覆盖在提词器界面之上。
/// 严格按思维导图分组：
/// 1. 进度条提示文字设置（对齐、显示项、字号）
/// 2. 正文显示设置（字间距/行距、加粗、强调效果）
/// 3. 阅读区域框设置（边框粗细、屏幕位置）
class TeleprompterSettingsPanel extends StatelessWidget {
  final VoidCallback onClose;

  const TeleprompterSettingsPanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 340,
        color: AppColors.surface,
        child: Consumer<SettingsProvider>(
          builder: (context, provider, _) {
            final settings = provider.mergedSettings;
            final isRemoteClient = context.watch<ConnectionProvider>().isRemote;
            return Column(
              children: [
                _buildTitleBar(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── 1. 进度条提示文字设置 ──
                      _buildSectionTitle(context, '进度条提示文字'),
                      const SizedBox(height: 8),
                      _buildProgressFontSizeSlider(context, provider, settings),
                      if (!isRemoteClient)
                        _buildScrollSpeedInput(context, provider, settings),
                      _buildProgressDisplayItems(context, provider, settings),
                      const Divider(height: 24),

                      // ── 2. 正文显示设置 ──
                      _buildSectionTitle(context, '正文显示'),
                      const SizedBox(height: 8),
                      _buildTeleprompterFontTile(context, provider, settings),
                      _buildBodyFontSizeInput(context, provider, settings),
                      _buildMirrorTextSwitch(context, provider, settings),
                      _buildLetterSpacingSlider(context, provider, settings),
                      _buildLineHeightSlider(context, provider, settings),
                      _buildExtraBoldSlider(context, provider, settings),
                      const SizedBox(height: 4),
                      _buildEmphasisSection(context, provider, settings),
                      const Divider(height: 24),

                      // ── 3. 阅读区域框设置 ──
                      _buildSectionTitle(context, '阅读区域框'),
                      const SizedBox(height: 8),
                      _buildReadingAreaBorderSlider(
                        context,
                        provider,
                        settings,
                      ),
                      _buildReadingAreaPositionSlider(
                        context,
                        provider,
                        settings,
                      ),
                      _buildTextPaddingSlider(context, provider, settings),
                    ],
                  ),
                ),
              ],
            );
          },
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
            onPressed: onClose,
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

  // ═══════════════════════════════════════════════════════
  // 1. 进度条提示文字设置
  // ═══════════════════════════════════════════════════════

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
    final controller = TextEditingController(text: '${settings.wpm}');
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
              controller: controller,
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
              final parsed = int.tryParse(controller.text.trim());
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

  // ═══════════════════════════════════════════════════════
  // 2. 正文显示设置
  // ═══════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════
  // 正文显示设置方法
  // ═══════════════════════════════════════════════════════

  /// 提词器正文字体选择
  Widget _buildTeleprompterFontTile(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    final fontService = FontService();

    return ListTile(
      dense: true,
      leading: const Icon(Icons.font_download, size: 20),
      title: const Text('正文字体', style: TextStyle(fontSize: 14)),
      subtitle: Text(
        settings.teleprompterFontFamily,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () {
        List<String> allFonts = [];
        List<String> filteredFonts = [];

        showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (context, dialogSetState) {
              if (allFonts.isEmpty) {
                fontService.getAvailableFonts().then((fonts) {
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
    AppSettings settings,
  ) {
    return _buildSlider(
      context,
      icon: Icons.space_bar,
      title: '字间距',
      value: settings.letterSpacing,
      min: -2,
      max: 10,
      divisions: 12,
      displayFormatter: (v) => '${v.toStringAsFixed(1)}px',
      onChanged: (v) => provider.setLetterSpacing(v),
      onReset: () => provider.setLetterSpacing(0),
    );
  }

  Widget _buildBodyFontSizeInput(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    final controller = TextEditingController(
      text: settings.fontSize.toStringAsFixed(
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
              controller: controller,
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
              final parsed = double.tryParse(controller.text.trim());
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
    AppSettings settings,
  ) {
    return _buildSlider(
      context,
      icon: Icons.format_line_spacing,
      title: '行距',
      value: settings.lineHeight,
      min: 1.0,
      max: 2.5,
      divisions: 15,
      displayFormatter: (v) => '${v.toStringAsFixed(1)}x',
      onChanged: (v) =>
          provider.setLineHeight(double.parse(v.toStringAsFixed(1))),
      onReset: () => provider.setLineHeight(1.5),
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
      subtitle: const Text('正文字体默认加粗', style: TextStyle(fontSize: 12)),
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
          subtitle: const Text(
            '高亮加粗当前正在阅读的字（默认关）',
            style: TextStyle(fontSize: 12),
          ),
          value: settings.highlightCurrentChar,
          onChanged: (_) => provider.toggleHighlightCurrentChar(),
        ),
        // 当前字加下划线（默认关）
        SwitchListTile(
          dense: true,
          secondary: const Icon(Icons.format_underlined, size: 20),
          title: const Text('当前字加下划线', style: TextStyle(fontSize: 14)),
          subtitle: const Text(
            '为当前字添加下划线效果（默认关）',
            style: TextStyle(fontSize: 12),
          ),
          value: settings.underlineCurrentChar,
          onChanged: (_) => provider.toggleUnderlineCurrentChar(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // 3. 阅读区域框设置
  // ═══════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════
  // 通用 Slider 组件
  // ═══════════════════════════════════════════════════════

  Widget _buildSlider(
    BuildContext context, {
    IconData? icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
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
}
