import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../services/asr_service.dart';
import '../theme/app_colors.dart';

/// 设置页面
///
/// 提供提词器参数、显示设置、ASR 模型等配置。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Consumer<SettingsProvider>(
        builder: (context, provider, _) {
          final settings = provider.settings;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 提词器设置分组
              _buildSectionHeader(context, '提词器设置'),
              const SizedBox(height: 12),

              _buildSliderTile(
                context,
                icon: Icons.format_size,
                title: '字体大小',
                value: settings.fontSize,
                min: 24,
                max: 120,
                divisions: 96,
                suffix: 'px',
                onChanged: (v) => provider.setFontSize(v.roundToDouble()),
                onReset: () => provider.setFontSize(48),
              ),

              _buildSliderTile(
                context,
                icon: Icons.format_line_spacing,
                title: '行高',
                value: settings.lineHeight,
                min: 1.0,
                max: 2.5,
                divisions: 15,
                suffix: 'x',
                onChanged: (v) =>
                    provider.setLineHeight(double.parse(v.toStringAsFixed(1))),
                onReset: () => provider.setLineHeight(1.5),
              ),

              _buildSliderTile(
                context,
                icon: Icons.speed,
                title: '自动滚动速度',
                value: settings.wpm.toDouble(),
                min: 30,
                max: 450,
                divisions: 84,
                suffix: ' 字/分',
                onChanged: (v) => provider.setWpm(v.round()),
                onReset: () => provider.setWpm(150),
              ),

              _buildSliderTile(
                context,
                icon: Icons.horizontal_distribute,
                title: '水平边距',
                value: settings.paddingX,
                min: 0,
                max: 40,
                divisions: 40,
                suffix: '%',
                onChanged: (v) => provider.setPaddingX(v),
                onReset: () => provider.setPaddingX(5),
              ),

              _buildSliderTile(
                context,
                icon: Icons.horizontal_rule,
                title: '阅读线偏移',
                value: settings.readingLineOffset,
                min: 0.05,
                max: 0.9,
                divisions: 85,
                suffix: '',
                displaySuffix: (v) => '${(v * 100).round()}%',
                onChanged: (v) => provider.setReadingLineOffset(v),
                onReset: () => provider.setReadingLineOffset(0.5),
              ),

              _buildSliderTile(
                context,
                icon: Icons.text_fields,
                title: '进度条字号比',
                value: settings.progressInfoSizeRatio,
                min: 0.3,
                max: 1.0,
                divisions: 70,
                suffix: '',
                displaySuffix: (v) => '${(v * 100).round()}%',
                onChanged: (v) => provider.setProgressInfoSizeRatio(v),
                onReset: () => provider.setProgressInfoSizeRatio(0.6),
              ),

              // 提词器背景色
              _buildColorPickerTile(
                context,
                icon: Icons.dark_mode,
                title: '提词器背景色',
                subtitle: '提词器页面背景颜色',
                currentColor: settings.teleprompterBgColor,
                onColorChanged: (c) => provider.setTeleprompterBgColor(c),
              ),

              // ── 文字外观 ──
              const SizedBox(height: 8),
              _buildFontFamilyTile(context, provider, settings),

              _buildSliderTile(
                context,
                icon: Icons.space_bar,
                title: '字间距',
                value: settings.letterSpacing,
                min: -2,
                max: 10,
                divisions: 12,
                suffix: '',
                displaySuffix: (v) => '${v.toStringAsFixed(1)}px',
                onChanged: (v) => provider.setLetterSpacing(v),
                onReset: () => provider.setLetterSpacing(0),
              ),

              _buildColorPickerTile(
                context,
                icon: Icons.palette_outlined,
                title: '字体颜色',
                subtitle: '0 = 自动根据背景色选择',
                currentColor: settings.textColor == 0
                    ? 0xFFF2F2F2
                    : settings.textColor,
                onColorChanged: (c) => provider.setTextColor(c),
              ),

              SwitchListTile(
                secondary: const Icon(Icons.opacity),
                title: const Text('已读字符变灰'),
                subtitle: const Text('已读过的字符变为半透明'),
                value: settings.grayReadChars,
                onChanged: (_) => provider.toggleGrayReadChars(),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.text_format),
                title: const Text('当前字高亮'),
                subtitle: const Text('高亮显示正在阅读的字符'),
                value: settings.highlightCurrentChar,
                onChanged: (_) => provider.toggleHighlightCurrentChar(),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.format_bold),
                title: const Text('默认加粗'),
                subtitle: const Text('正文字体默认加粗，已设置粗体的再加粗'),
                value: settings.defaultBold,
                onChanged: (_) => provider.toggleDefaultBold(),
              ),

              const SizedBox(height: 24),
              _buildSectionHeader(context, '应用设置'),
              const SizedBox(height: 12),

              // 主题色选择
              _buildColorPickerTile(
                context,
                icon: Icons.palette,
                title: '主题色',
                subtitle: '应用全局主色调',
                currentColor: settings.uiPrimaryColor,
                onColorChanged: (c) => provider.setUiPrimaryColor(c),
              ),

              const SizedBox(height: 8),

              // 镜像模式
              SwitchListTile(
                secondary: const Icon(Icons.flip),
                title: const Text('镜像翻转'),
                subtitle: const Text('用于提词器分光镜场景'),
                value: settings.mirrorMode,
                onChanged: (_) => provider.toggleMirrorMode(),
              ),

              // 自动隐藏界面
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off),
                title: const Text('自动隐藏界面'),
                subtitle: const Text('播放时自动隐藏控制面板，点击屏幕重新显示'),
                value: settings.autoHideUI,
                onChanged: (_) => provider.toggleAutoHideUI(),
              ),

              // 进入提词器时自动全屏
              SwitchListTile(
                secondary: const Icon(Icons.fullscreen),
                title: const Text('自动全屏'),
                subtitle: const Text('进入提词器页面时自动进入全屏模式'),
                value: settings.fullScreenMode,
                onChanged: (_) => provider.toggleFullScreenMode(),
              ),

              if (settings.autoHideUI)
                _buildSliderTile(
                  context,
                  icon: Icons.timer,
                  title: '自动隐藏延迟',
                  value: settings.autoHideDelaySeconds.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  suffix: ' 秒',
                  onChanged: (v) => provider.setAutoHideDelay(v.round()),
                  onReset: () => provider.setAutoHideDelay(3),
                ),

              const SizedBox(height: 24),
              _buildSectionHeader(context, 'ASR 语音识别'),
              const SizedBox(height: 12),

              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('语音识别模型'),
                subtitle: Text(
                  settings.asrModelName.isEmpty
                      ? '未选择模型'
                      : settings.asrModelName,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAsrModelSelector(context, provider),
              ),

              const SizedBox(height: 16),
              _buildMirrorUrlField(settings, provider),

              const SizedBox(height: 32),

              // 完全重置
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('重置所有设置为默认值'),
                  onPressed: () => provider.resetAllSettings(),
                ),
              ),

              const SizedBox(height: 32),

              // 关于
              _buildSectionHeader(context, '关于'),
              const SizedBox(height: 12),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('飓风提词器 Plus'),
                subtitle: Text('版本 1.0.0\n基于 Flutter 构建的智能提词器'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _buildSectionHeader(BuildContext context, String title) {
    final primary = Theme.of(context).colorScheme.primary;
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: 0.5,
      ),
    );
  }

  /// 正文字体选择 Tile
  static Widget _buildFontFamilyTile(
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.font_download,
            size: 22,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('正文字体', style: TextStyle(fontSize: 15)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: settings.fontFamily,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
                  onChanged: (v) {
                    if (v != null) provider.setFontFamily(v);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSliderTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    String Function(double)? displaySuffix,
    required ValueChanged<double> onChanged,
    VoidCallback? onReset,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final displayText = displaySuffix != null
        ? displaySuffix(value)
        : '${value.round()}$suffix';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.textSecondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15)),
                Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: displayText,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              displayText,
              textAlign: TextAlign.right,
              style: TextStyle(color: primary, fontWeight: FontWeight.w600),
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

  /// 预设颜色列表
  static const List<int> _presetColors = [
    // 标准色
    0xFFFFFFFF, // 白色
    0xFFBDBDBD, // 浅灰
    0xFF757575, // 灰色
    0xFF212121, // 近黑
    0xFF000000, // 黑色
    // 彩色
    0xFFDB9D16, // 金色（默认）
    0xFFE53935, // 红色
    0xFFD81B60, // 粉色
    0xFF8E24AA, // 紫色
    0xFF5E35B1, // 深紫
    0xFF3949AB, // 靛蓝
    0xFF1E88E5, // 蓝色
    0xFF00ACC1, // 青色
    0xFF00897B, // 青绿
    0xFF43A047, // 绿色
    0xFF7CB342, // 草绿
    0xFFFDD835, // 黄色
    0xFFFB8C00, // 橙色
    0xFF6D4C41, // 棕色
    0xFF546E7A, // 蓝灰
  ];

  /// 预设 GitHub 镜像源
  static const List<Map<String, String>> _presetMirrors = [
    {'label': 'gh-proxy.com', 'url': 'https://gh-proxy.com/'},
    {'label': 'hk.gh-proxy.com', 'url': 'https://hk.gh-proxy.com/'},
    {'label': 'ghproxy.net', 'url': 'https://ghproxy.net/'},
    {'label': 'ghps.cc', 'url': 'https://ghps.cc/'},
    {'label': '镜像（自定义）', 'url': ''},
  ];

  /// 镜像 URL 输入框（含预设选择）
  static Widget _buildMirrorUrlField(
    AppSettings settings,
    SettingsProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GitHub 下载镜像',
            style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            '用于加速 ASR 模型下载，留空使用原始地址',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          // 预设镜像选择
          DropdownButtonFormField<String>(
            initialValue: settings.asrMirrorUrl,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            hint: const Text('选择镜像源', style: TextStyle(fontSize: 13)),
            isExpanded: true,
            items: _presetMirrors.map((m) {
              return DropdownMenuItem<String>(
                value: m['url']!,
                child: Text(m['label']!, style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                provider.setAsrMirrorUrl(value);
              }
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: settings.asrMirrorUrl),
            decoration: const InputDecoration(
              hintText: 'https://gh-proxy.com/',
              labelText: '自定义镜像地址',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
            onSubmitted: (value) => provider.setAsrMirrorUrl(value.trim()),
          ),
        ],
      ),
    );
  }

  /// 颜色选择器 Tile
  static Widget _buildColorPickerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required int currentColor,
    required ValueChanged<int> onColorChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.textSecondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetColors.map((color) {
                    final isSelected = color == currentColor;
                    return GestureDetector(
                      onTap: () => onColorChanged(color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(color),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.textPrimary,
                                  width: 2,
                                )
                              : Border.all(color: AppColors.border, width: 1),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Color(color).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                size: 18,
                                color: Color(color).computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _showAsrModelSelector(
    BuildContext context,
    SettingsProvider provider,
  ) {
    final asr = AsrService.instance;
    final currentModelId = provider.settings.asrModelId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final primary = Theme.of(ctx).colorScheme.primary;
          return AlertDialog(
            title: const Text('选择 ASR 模型'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...AsrModels.availableModels.map((model) {
                    final isSelected = currentModelId == model.id;
                    return FutureBuilder<bool>(
                      future: asr.isModelDownloaded(model.id),
                      builder: (context, snapshot) {
                        final downloaded = snapshot.data ?? false;
                        // 使用 ListenableBuilder 订阅 AsrService 的下载进度
                        return ListenableBuilder(
                          listenable: asr,
                          builder: (context, _) {
                            final downloadState = asr.getDownloadProgress(
                              model.id,
                            );
                            final isDownloading = downloadState.isDownloading;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: isSelected
                                  ? primary.withValues(alpha: 0.15)
                                  : null,
                              child: ListTile(
                                leading: Icon(
                                  downloaded
                                      ? Icons.check_circle
                                      : isDownloading
                                      ? Icons.downloading
                                      : Icons.cloud_download,
                                  color: downloaded
                                      ? AppColors.success
                                      : isDownloading
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                                title: Text(
                                  model.name,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? primary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${model.description}\n'
                                      '约 ${model.approximateSizeMB} MB',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    if (isDownloading ||
                                        downloadState.error != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            LinearProgressIndicator(
                                              value: downloadState.progress > 0
                                                  ? downloadState.progress
                                                  : null,
                                              backgroundColor: AppColors.border,
                                              color: AppColors.primary,
                                              minHeight: 4,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              downloadState.message,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                isThreeLine:
                                    isDownloading ||
                                    downloadState.error != null,
                                trailing: isDownloading
                                    ? IconButton(
                                        icon: const Icon(Icons.close, size: 20),
                                        tooltip: '取消下载',
                                        onPressed: () => asr.cancelDownload(),
                                        style: IconButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                          padding: EdgeInsets.zero,
                                        ),
                                      )
                                    : isSelected
                                    ? Icon(Icons.check, color: primary)
                                    : null,
                                onTap: () async {
                                  if (downloaded) {
                                    // 已下载：直接选择并加载
                                    await provider.setAsrModel(
                                      model.id,
                                      model.name,
                                    );
                                    try {
                                      await asr.loadModel(model.id);
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text('模型加载失败: $e')),
                                        );
                                      }
                                    }
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } else if (!isDownloading) {
                                    // 未下载且不在下载中：开始下载
                                    final customMirror =
                                        provider.settings.asrMirrorUrl;
                                    asr
                                        .downloadModel(
                                          model,
                                          useMirror: true,
                                          customMirrorUrl:
                                              customMirror.isNotEmpty
                                              ? customMirror
                                              : null,
                                        )
                                        .then((_) async {
                                          await provider.setAsrModel(
                                            model.id,
                                            model.name,
                                          );
                                          try {
                                            await asr.loadModel(model.id);
                                          } catch (_) {}
                                        })
                                        .catchError((e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text('下载失败: $e'),
                                              ),
                                            );
                                          }
                                        });
                                  }
                                },
                              ),
                            );
                          },
                        );
                      },
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
            ],
          );
        },
      ),
    );
  }
}
