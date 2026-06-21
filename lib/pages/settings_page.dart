import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../providers/connection_provider.dart';
import '../services/asr_service.dart';
import '../services/font_service.dart';
import '../theme/app_colors.dart';

/// 应用设置页面
///
/// 严格按思维导图结构：
/// - 应用主题（全功能颜色选取器）
/// - 应用字体
/// - 下载ASR模型
/// - 后端共享配置（公开到局域网、连接信息查看、已连接设备查看）
/// - 重置所有设置（可选包括提词器设置）
/// - 关于/帮助/检查更新/License
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('应用设置')),
        body: Consumer2<SettingsProvider, ConnectionProvider>(
          builder: (context, provider, connection, _) {
            final settings = provider.settings;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── 应用主题 ──
                _buildSectionHeader(context, '应用主题'),
                const SizedBox(height: 12),
                _buildThemeColorTile(context, provider, settings),

                const SizedBox(height: 24),

                // ── 应用字体 ──
                _buildSectionHeader(context, '应用字体'),
                const SizedBox(height: 12),
                _buildFontFamilyTile(context, provider, settings),

                const SizedBox(height: 24),

                // ── 下载 ASR 模型（仅本地模式） ──
                if (!connection.isRemote) ...[
                  _buildSectionHeader(context, '语音识别模型'),
                  const SizedBox(height: 12),
                  _buildAsrSection(context, provider, settings),
                  const SizedBox(height: 24),
                ],

                // ── 后端共享配置（仅本地模式） ──
                if (!connection.isRemote) ...[
                  _buildSectionHeader(context, '后端共享配置'),
                  const SizedBox(height: 12),
                  _buildBackendSection(context, connection),
                  const SizedBox(height: 24),
                ],

                // ── 重置所有设置 ──
                _buildSectionHeader(context, '重置'),
                const SizedBox(height: 12),
                _buildResetSection(context, provider),

                const SizedBox(height: 24),

                // ── 关于 ──
                _buildSectionHeader(context, '关于'),
                const SizedBox(height: 12),
                _buildAboutSection(context),
              ],
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 应用主题 - 全功能颜色选取器
  // ═══════════════════════════════════════════════════════

  Widget _buildThemeColorTile(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primaryFromSettings(settings.uiPrimaryColor),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
      ),
      title: const Text('主题色'),
      subtitle: Text(
        '#${settings.uiPrimaryColor.toRadixString(16).padLeft(8, '0').toUpperCase()}',
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showColorPicker(
        context,
        currentColor: Color(settings.uiPrimaryColor),
        onColorSelected: (color) =>
            provider.setUiPrimaryColor(color.toARGB32()),
      ),
    );
  }

  /// 全功能颜色选取器对话框
  void _showColorPicker(
    BuildContext context, {
    required Color currentColor,
    required ValueChanged<Color> onColorSelected,
  }) {
    Color pickerColor = currentColor;
    String? hexError;
    final hexController = TextEditingController(text: _formatHex(currentColor));

    Color? parseHex(String value) {
      final normalized = value.trim().replaceFirst('#', '');
      if (normalized.length != 6 && normalized.length != 8) return null;
      final argb = normalized.length == 6 ? 'FF$normalized' : normalized;
      final parsed = int.tryParse(argb, radix: 16);
      return parsed == null ? null : Color(parsed);
    }

    void syncHex(Color color) {
      final text = _formatHex(color);
      hexController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('选择颜色'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ColorPicker(
                  pickerColor: pickerColor,
                  onColorChanged: (color) => setDialogState(() {
                    pickerColor = color;
                    hexError = null;
                    syncHex(color);
                  }),
                  enableAlpha: true,
                  displayThumbColor: true,
                  pickerAreaHeightPercent: 0.8,
                  portraitOnly: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hexController,
                  decoration: InputDecoration(
                    labelText: 'HEX',
                    hintText: '#AARRGGBB 或 #RRGGBB',
                    errorText: hexError,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F#]')),
                  ],
                  maxLength: 9,
                  onChanged: (value) {
                    final parsed = parseHex(value);
                    setDialogState(() {
                      hexError = parsed == null ? '请输入 6 或 8 位十六进制颜色' : null;
                      if (parsed != null) pickerColor = parsed;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                onColorSelected(pickerColor);
                Navigator.pop(ctx);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    ).whenComplete(hexController.dispose);
  }

  // ═══════════════════════════════════════════════════════
  // 应用字体
  // ═══════════════════════════════════════════════════════

  String _formatHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  Widget _buildFontFamilyTile(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    return ListTile(
      leading: const Icon(Icons.font_download),
      title: const Text('应用字体'),
      subtitle: Text(
        settings.appFontFamily.isEmpty ? '系统默认' : settings.appFontFamily,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showFontSelector(context, provider, settings, 'app'),
    );
  }

  /// 显示带搜索的字体选择对话框
  void _showFontSelector(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
    String mode,
  ) {
    final fontService = FontService();
    List<String> allFonts = [];
    List<String> filteredFonts = [];
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          // 首次加载系统字体
          if (allFonts.isEmpty) {
            fontService.getAvailableFonts().then((fonts) {
              dialogSetState(() {
                allFonts = fonts;
                filteredFonts = fonts;
              });
            });
          }

          final currentFont = mode == 'app'
              ? settings.appFontFamily
              : settings.teleprompterFontFamily;

          return AlertDialog(
            title: Text(mode == 'app' ? '选择应用字体' : '选择提词字体'),
            contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
            content: SizedBox(
              width: 350,
              height: 400,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: '搜索字体... (${allFonts.length}个)',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        searchQuery = value;
                        fontService.searchFonts(value).then((fonts) {
                          dialogSetState(() => filteredFonts = fonts);
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filteredFonts.isEmpty
                        ? const Center(child: Text('没有找到匹配的字体'))
                        : ListView.builder(
                            itemCount: filteredFonts.length,
                            itemBuilder: (context, index) {
                              final f = filteredFonts[index];
                              final isSelected = f == currentFont;
                              return ListTile(
                                dense: true,
                                title: Text(
                                  f,
                                  style: TextStyle(
                                    fontFamily: f,
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
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
                                  if (mode == 'app') {
                                    provider.setAppFontFamily(f);
                                  } else {
                                    provider.setTeleprompterFontFamily(f);
                                  }
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
  }

  // ═══════════════════════════════════════════════════════
  // 下载 ASR 模型
  // ═══════════════════════════════════════════════════════

  Widget _buildAsrSection(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.mic),
          title: const Text('语音识别模型'),
          subtitle: Text(
            settings.asrModelName.isEmpty ? '未选择模型' : settings.asrModelName,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showAsrModelSelector(context, provider),
        ),
      ],
    );
  }

  static void _showAsrModelSelector(
    BuildContext context,
    SettingsProvider provider,
  ) {
    final asr = AsrService.instance;
    final currentModelId = provider.settings.asrModelId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) {
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '选择 ASR 模型',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: AsrModels.availableModels.length,
                  itemBuilder: (ctx, index) {
                    final model = AsrModels.availableModels[index];
                    final isSelected = model.id == currentModelId;
                    final progress = asr.getDownloadProgress(model.id);

                    return ListTile(
                      title: Text(model.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(model.description),
                          Text(
                            '约 ${model.approximateSizeMB} MB',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          if (progress.isDownloading)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: LinearProgressIndicator(
                                value: progress.progress,
                              ),
                            ),
                          if (progress.isCompleted)
                            const Text(
                              '已下载',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                              ),
                            ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                            ),
                          if (!progress.isCompleted && !progress.isDownloading)
                            IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: () async {
                                await asr.downloadModel(model);
                                if (ctx.mounted) {
                                  provider.setAsrModel(model.id, model.name);
                                }
                              },
                            ),
                        ],
                      ),
                      onTap: isSelected
                          ? null
                          : () {
                              if (progress.isCompleted) {
                                provider.setAsrModel(model.id, model.name);
                                Navigator.pop(ctx);
                              }
                            },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 后端共享配置
  // ═══════════════════════════════════════════════════════

  Widget _buildBackendSection(
    BuildContext context,
    ConnectionProvider connection,
  ) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return Column(
          children: [
            // 公开到局域网
            SwitchListTile(
              secondary: const Icon(Icons.wifi),
              title: const Text('公开到局域网'),
              subtitle: Text(
                settingsProvider.settings.isLanPublished ? '服务运行中' : '已关闭',
              ),
              value: settingsProvider.settings.isLanPublished,
              onChanged: (value) {
                settingsProvider.setLanPublished(value);
              },
            ),

            // 连接信息查看
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('连接信息'),
              subtitle: Text(connection.connectionInfoText),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showConnectionInfoDialog(context, connection),
            ),

            // 已连接设备查看
            ListTile(
              leading: const Icon(Icons.devices),
              title: const Text('已连接设备'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${connection.deviceCount}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => _showDevicesDialog(context, connection),
            ),
          ],
        );
      },
    );
  }

  /// 连接信息对话框
  void _showConnectionInfoDialog(
    BuildContext context,
    ConnectionProvider connection,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('连接信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('状态', connection.isConnected ? '已连接' : '未连接'),
            _infoRow('模式', connection.isRemote ? '远程后端' : '本地后端'),
            _infoRow('连接详情', connection.connectionInfoText),
            if (connection.clientId != null)
              _infoRow('客户端 ID', connection.clientId!),
            _infoRow('已连接设备数', '${connection.deviceCount}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 已连接设备对话框
  void _showDevicesDialog(BuildContext context, ConnectionProvider connection) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('已连接设备'),
        content: SizedBox(
          width: 300,
          child: connection.deviceCount == 0
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      '暂无其他设备连接',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 当前设备
                    ListTile(
                      leading: const Icon(Icons.computer, size: 20),
                      title: Text('本机 (${connection.clientId ?? "未知"})'),
                      subtitle: const Text('当前设备'),
                      dense: true,
                    ),
                    if (connection.deviceCount > 1) const Divider(),
                    // 其他设备
                    ...List.generate(
                      connection.deviceCount > 1
                          ? connection.deviceCount - 1
                          : 0,
                      (i) => ListTile(
                        leading: const Icon(Icons.devices_other, size: 20),
                        title: Text('设备 ${i + 2}'),
                        subtitle: const Text('远程连接'),
                        dense: true,
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
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 重置设置
  // ═══════════════════════════════════════════════════════

  Widget _buildResetSection(BuildContext context, SettingsProvider provider) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('重置所有设置'),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('重置设置'),
                  content: const Text('确定要重置所有设置为默认值吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        provider.resetAllSettings();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('设置已重置')));
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      child: const Text('重置'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // 关于
  // ═══════════════════════════════════════════════════════

  Widget _buildAboutSection(BuildContext context) {
    return const Column(
      children: [
        ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('飓风提词器 Plus'),
          subtitle: Text('版本 1.0.0\n基于 Flutter 构建的智能提词器'),
        ),
        ListTile(
          leading: Icon(Icons.help_outline),
          title: Text('帮助'),
          subtitle: Text('查看使用说明'),
        ),
        ListTile(
          leading: Icon(Icons.update),
          title: Text('检查更新'),
          subtitle: Text('当前版本 1.0.0'),
        ),
        ListTile(
          leading: Icon(Icons.description_outlined),
          title: Text('License'),
          subtitle: Text('MIT License'),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // 工具方法
  // ═══════════════════════════════════════════════════════

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

  static Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
