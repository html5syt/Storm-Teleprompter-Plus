import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

/// 提词器设置面板（抽屉形式）
///
/// 从右侧滑入，覆盖在提词器界面之上。
/// 仅包含提词器相关设置（不含应用全局设置 / ASR / 关于）。
class TeleprompterSettingsPanel extends StatelessWidget {
  final VoidCallback onClose;

  const TeleprompterSettingsPanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // 拦截点击
      child: Container(
        width: 340,
        color: AppColors.surface,
        child: Consumer<SettingsProvider>(
          builder: (context, provider, _) {
            final settings = provider.settings;
            return Column(
              children: [
                // ── 标题栏 ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.3),
                      ),
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
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ),
                // ── 内容 ──
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSectionTitle(context, '提词器设置'),
                      const SizedBox(height: 8),
                      _buildSlider(
                        context,
                        '字体大小',
                        settings.fontSize,
                        24,
                        120,
                        96,
                        'px',
                        (v) => provider.setFontSize(v.roundToDouble()),
                        onReset: () => provider.setFontSize(48),
                      ),
                      _buildSlider(
                        context,
                        '行高',
                        settings.lineHeight,
                        1.0,
                        2.5,
                        15,
                        'x',
                        (v) => provider.setLineHeight(
                          double.parse(v.toStringAsFixed(1)),
                        ),
                        onReset: () => provider.setLineHeight(1.5),
                      ),
                      _buildSlider(
                        context,
                        '自动滚动速度',
                        settings.wpm.toDouble(),
                        30,
                        450,
                        84,
                        ' 字/分',
                        (v) => provider.setWpm(v.round()),
                        onReset: () => provider.setWpm(150),
                      ),
                      _buildSlider(
                        context,
                        '水平边距',
                        settings.paddingX,
                        0,
                        40,
                        40,
                        '%',
                        (v) => provider.setPaddingX(v),
                        onReset: () => provider.setPaddingX(5),
                      ),
                      _buildSlider(
                        context,
                        '阅读线偏移',
                        settings.readingLineOffset,
                        0.05,
                        0.9,
                        85,
                        '',
                        (v) => provider.setReadingLineOffset(v),
                        displayFormatter: (v) => '${(v * 100).round()}%',
                        onReset: () => provider.setReadingLineOffset(0.5),
                      ),
                      _buildSlider(
                        context,
                        '进度条字号比例',
                        settings.progressInfoSizeRatio,
                        0.3,
                        1.0,
                        70,
                        '',
                        (v) => provider.setProgressInfoSizeRatio(v),
                        displayFormatter: (v) => '${(v * 100).round()}%',
                        onReset: () => provider.setProgressInfoSizeRatio(0.6),
                      ),
                      // ── 显示与行为 ──
                      const Divider(height: 24),
                      _buildSectionTitle(context, '显示与行为'),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        dense: true,
                        secondary: const Icon(Icons.flip, size: 20),
                        title: const Text(
                          '镜像翻转',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          '用于提词器分光镜场景',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: settings.mirrorMode,
                        onChanged: (_) => provider.toggleMirrorMode(),
                      ),
                      SwitchListTile(
                        dense: true,
                        secondary: const Icon(Icons.visibility_off, size: 20),
                        title: const Text(
                          '自动隐藏界面',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          '播放时自动隐藏控制面板',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: settings.autoHideUI,
                        onChanged: (_) => provider.toggleAutoHideUI(),
                      ),
                      if (settings.autoHideUI)
                        _buildSlider(
                          context,
                          '隐藏延迟',
                          settings.autoHideDelaySeconds.toDouble(),
                          1,
                          10,
                          9,
                          ' 秒',
                          (v) => provider.setAutoHideDelay(v.round()),
                          onReset: () => provider.setAutoHideDelay(3),
                        ),
                      SwitchListTile(
                        dense: true,
                        secondary: const Icon(Icons.fullscreen, size: 20),
                        title: const Text(
                          '自动全屏',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          '进入提词器时自动全屏',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: settings.fullScreenMode,
                        onChanged: (_) => provider.toggleFullScreenMode(),
                      ),
                      // ── 文字外观 ──
                      const Divider(height: 24),
                      _buildSectionTitle(context, '文字外观'),
                      const SizedBox(height: 8),
                      _buildFontFamilyField(context, provider, settings),
                      _buildSlider(
                        context,
                        '字间距',
                        settings.letterSpacing,
                        -2,
                        10,
                        12,
                        'px',
                        (v) => provider.setLetterSpacing(v),
                        displayFormatter: (v) => '${v.toStringAsFixed(1)}px',
                        onReset: () => provider.setLetterSpacing(0),
                      ),
                      _buildColorTile(
                        context,
                        '字体颜色',
                        settings.textColor == 0
                            ? 0xFFF2F2F2
                            : settings.textColor,
                        (c) => provider.setTextColor(c),
                        allowTransparent: false,
                      ),
                      SwitchListTile(
                        dense: true,
                        secondary: const Icon(Icons.opacity, size: 20),
                        title: const Text(
                          '已读字符变灰',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          '已读过的字符变为半透明',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: settings.grayReadChars,
                        onChanged: (_) => provider.toggleGrayReadChars(),
                      ),
                      SwitchListTile(
                        dense: true,
                        secondary: const Icon(Icons.text_format, size: 20),
                        title: const Text(
                          '当前字高亮',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          '高亮显示正在阅读的字符',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: settings.highlightCurrentChar,
                        onChanged: (_) => provider.toggleHighlightCurrentChar(),
                      ),
                      SwitchListTile(
                        dense: true,
                        secondary: const Icon(Icons.format_bold, size: 20),
                        title: const Text(
                          '默认加粗',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          '正文字体默认加粗，已设置粗体的再加粗',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: settings.defaultBold,
                        onChanged: (_) => provider.toggleDefaultBold(),
                      ),
                      // ── 重置设置 ──
                      const Divider(height: 24),
                      _buildSectionTitle(context, '重置设置'),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.restart_alt, size: 18),
                          label: const Text('重置所有设置为默认值'),
                          onPressed: () => provider.resetAllSettings(),
                        ),
                      ),
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

  Widget _buildSlider(
    BuildContext context,
    String title,
    double value,
    double min,
    double max,
    int divisions,
    String suffix,
    ValueChanged<double> onChanged, {
    String Function(double)? displayFormatter,
    VoidCallback? onReset,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final display = displayFormatter != null
        ? displayFormatter(value)
        : '${value.round()}$suffix';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
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

  Widget _buildFontFamilyField(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    const presetFonts = [
      '',
      'Noto Sans SC',
      'Noto Serif SC',
      '思源黑体',
      '思源宋体',
      'Microsoft YaHei',
      'SimSun',
      'KaiTi',
      'FangSong',
      'Roboto',
      'Arial',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '正文字体',
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: settings.fontFamily,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              isDense: true,
            ),
            hint: const Text('系统默认', style: TextStyle(fontSize: 13)),
            isExpanded: true,
            items: presetFonts.map((f) {
              return DropdownMenuItem<String>(
                value: f,
                child: Text(
                  f.isEmpty ? '系统默认' : f,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: f.isNotEmpty ? f : null,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) provider.setFontFamily(value);
            },
          ),
        ],
      ),
    );
  }

  /// 颜色选取 Tile
  Widget _buildColorTile(
    BuildContext context,
    String title,
    int currentColor,
    ValueChanged<int> onColorChanged, {
    bool allowTransparent = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Color(currentColor),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border, width: 1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _showColorPickerDialog(
              context,
              currentColor,
              onColorChanged,
              allowTransparent: allowTransparent,
            ),
            child: const Text('选择', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  /// 标准颜色选择器对话框
  void _showColorPickerDialog(
    BuildContext context,
    int currentColor,
    ValueChanged<int> onColorChanged, {
    bool allowTransparent = true,
  }) {
    Color selectedColor = Color(currentColor);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('选择颜色'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: selectedColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetColors.map((c) {
                    final isSelected = c == selectedColor.toARGB32();
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = Color(c)),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(c),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  '或输入 Hex 颜色',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    hintText: '#FFDB9D16',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                  onSubmitted: (value) {
                    final hex = value.replaceFirst('#', '');
                    if (hex.length == 6 || hex.length == 8) {
                      final parsed = int.tryParse(
                        hex.length == 6 ? 'FF$hex' : hex,
                        radix: 16,
                      );
                      if (parsed != null) {
                        setState(() => selectedColor = Color(parsed));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (allowTransparent)
              TextButton(
                onPressed: () {
                  onColorChanged(0);
                  Navigator.pop(ctx);
                },
                child: const Text('重置'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                onColorChanged(selectedColor.toARGB32());
                Navigator.pop(ctx);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  static const List<int> _presetColors = [
    0xFFDB9D16,
    0xFFE53935,
    0xFFD81B60,
    0xFF8E24AA,
    0xFF5E35B1,
    0xFF3949AB,
    0xFF1E88E5,
    0xFF00ACC1,
    0xFF00897B,
    0xFF43A047,
    0xFF7CB342,
    0xFFFDD835,
    0xFFFB8C00,
    0xFF6D4C41,
    0xFF546E7A,
    0xFF424242,
  ];
}
