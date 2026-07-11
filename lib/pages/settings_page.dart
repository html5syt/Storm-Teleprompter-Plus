import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
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
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.maybePop(context);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.backgroundFor(context),
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
                  _buildBrightnessModeTile(context, provider, settings),

                  const SizedBox(height: 24),

                  // ── 应用字体 ──
                  _buildSectionHeader(context, '应用字体'),
                  const SizedBox(height: 12),
                  _buildFontFamilyTile(context, provider, settings),

                  const SizedBox(height: 24),

                  // ── 下载 ASR 模型（仅本地模式） ──
                  if (!connection.isRemote && !kIsWeb) ...[
                    _buildSectionHeader(context, '语音识别模型'),
                    const SizedBox(height: 12),
                    _buildAsrSection(context, provider, settings),
                    const SizedBox(height: 24),
                  ],

                  // ── 服务连接（仅本机服务端模式） ──
                  if (!connection.isRemote) ...[
                    _buildSectionHeader(context, '服务连接'),
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
          border: Border.all(color: AppColors.borderFor(context)),
        ),
      ),
      title: const Text('主题色'),
      subtitle: Text(
        '#${settings.uiPrimaryColor.toRadixString(16).padLeft(8, '0').toUpperCase()}',
        style: TextStyle(fontSize: 12, color: AppColors.textMutedFor(context)),
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

  Widget _buildBrightnessModeTile(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    final label = switch (settings.appBrightnessMode) {
      AppBrightnessMode.system => '自动',
      AppBrightnessMode.light => '白天',
      AppBrightnessMode.dark => '夜间',
    };
    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: const Text('亮暗模式'),
      subtitle: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBrightnessOption(
                  ctx,
                  provider,
                  settings,
                  AppBrightnessMode.system,
                  '自动',
                  subtitle: '跟随系统',
                ),
                _buildBrightnessOption(
                  ctx,
                  provider,
                  settings,
                  AppBrightnessMode.light,
                  '白天',
                ),
                _buildBrightnessOption(
                  ctx,
                  provider,
                  settings,
                  AppBrightnessMode.dark,
                  '夜间',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBrightnessOption(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
    AppBrightnessMode mode,
    String title, {
    String? subtitle,
  }) {
    final selected = settings.appBrightnessMode == mode;
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: () {
        provider.setAppBrightnessMode(mode);
        Navigator.pop(context);
      },
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
    );
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          // 首次加载系统字体
          if (allFonts.isEmpty) {
            fontService.getAvailableFonts().then((fonts) {
              if (!context.mounted) return;
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
        ListTile(
          leading: const Icon(Icons.file_upload_outlined),
          title: const Text('从本地导入模型'),
          subtitle: const Text('支持 Sherpa-Onnx .zip、.tar.bz2 模型包'),
          onTap: () => _importAsrModel(context, provider),
        ),
        ListTile(
          leading: const Icon(Icons.mic_outlined),
          title: const Text('麦克风设备'),
          subtitle: Text(
            settings.asrInputDeviceName.isEmpty
                ? '系统默认设备'
                : settings.asrInputDeviceName,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showInputDeviceSelector(context, provider),
        ),
        ListTile(
          leading: const Icon(Icons.tune),
          title: const Text('下载与高级设置'),
          subtitle: Text(
            '${settings.asrMirrorUrl.isEmpty ? '原始下载源' : '自定义镜像'} · '
            '${settings.asrUseSystemProxy ? '系统代理' : '直连'} · '
            '${settings.asrNumThreads == 0 ? '自动线程数' : '${settings.asrNumThreads} 线程'}',
          ),
          onTap: () => _showAsrAdvancedSettings(context, provider),
        ),
      ],
    );
  }

  static Future<void> _showAsrModelSelector(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final asr = AsrService.instance;
    var currentModelId = provider.settings.asrModelId;
    if (currentModelId.isNotEmpty &&
        !await asr.isModelDownloaded(currentModelId)) {
      await provider.clearAsrModel();
      currentModelId = '';
    }
    if (!context.mounted) return;
    final recommendedModelId = asr.recommendModel().id;
    final downloadedChecks = <String, Future<bool>>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AnimatedBuilder(
        animation: asr,
        builder: (ctx, _) => DraggableScrollableSheet(
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
                      final anyDownloading = asr.allDownloadProgress.values.any(
                        (item) => item.isDownloading,
                      );

                      return FutureBuilder<bool>(
                        future: downloadedChecks.putIfAbsent(
                          model.id,
                          () => asr.isModelDownloaded(model.id),
                        ),
                        builder: (context, downloadedSnapshot) {
                          final isDownloaded =
                              downloadedSnapshot.data == true ||
                              progress.isCompleted;
                          return InkWell(
                            onTap: isSelected || !isDownloaded
                                ? null
                                : () {
                                    provider.setAsrModel(model.id, model.name);
                                    Navigator.pop(ctx);
                                  },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          model.name,
                                          style: Theme.of(
                                            ctx,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(model.description),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${model.languages} · ${model.scenario}\n'
                                          '准确率 ${model.accuracy} · 延迟 ${model.latency} · '
                                          '约 ${model.approximateSizeMB} MB · 建议内存 ${model.recommendedMemoryMB} MB',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMutedFor(ctx),
                                          ),
                                        ),
                                        if (progress.isDownloading) ...[
                                          const SizedBox(height: 6),
                                          LinearProgressIndicator(
                                            value: progress.progress,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            progress.message,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                        if (isDownloaded)
                                          const Text(
                                            '已下载',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        if (!isDownloaded &&
                                            !progress.isDownloading)
                                          Text(
                                            progress.error == null
                                                ? '未下载'
                                                : progress.message,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: progress.error == null
                                                  ? AppColors.textMutedFor(ctx)
                                                  : AppColors.error,
                                            ),
                                          ),
                                        if (model.id == recommendedModelId)
                                          const Text(
                                            '根据本机处理器性能推荐',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.success,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle,
                                          color: AppColors.success,
                                        ),
                                      if (!isDownloaded &&
                                          !progress.isDownloading)
                                        IconButton(
                                          icon: const Icon(Icons.download),
                                          tooltip: '下载模型',
                                          onPressed: anyDownloading
                                              ? null
                                              : () async {
                                                  await _downloadAsrModel(
                                                    ctx,
                                                    asr,
                                                    provider,
                                                    model,
                                                  );
                                                },
                                        ),
                                      if (isDownloaded &&
                                          !progress.isDownloading)
                                        IconButton(
                                          icon: const Icon(Icons.refresh),
                                          tooltip: '重新下载或更新',
                                          onPressed: anyDownloading
                                              ? null
                                              : () async {
                                                  await _downloadAsrModel(
                                                    ctx,
                                                    asr,
                                                    provider,
                                                    model,
                                                  );
                                                },
                                        ),
                                      if (progress.isDownloading)
                                        IconButton(
                                          icon: const Icon(Icons.close),
                                          tooltip: '取消下载',
                                          onPressed: () {
                                            unawaited(asr.cancelDownload());
                                          },
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static Future<void> _downloadAsrModel(
    BuildContext context,
    AsrService asr,
    SettingsProvider provider,
    AsrModelInfo model,
  ) async {
    try {
      await asr.downloadModel(
        model,
        customMirrorUrl: provider.settings.asrMirrorUrl,
        useSystemProxy: provider.settings.asrUseSystemProxy,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('模型下载失败：$error')));
    }
  }

  static Future<void> showInputDeviceSelector(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final asr = AsrService.instance;
    List<InputDevice> devices;
    try {
      devices = await asr.listInputDevices();
      final selectedId = provider.settings.asrInputDeviceId;
      if (selectedId.isNotEmpty &&
          !devices.any((device) => device.id == selectedId)) {
        await provider.setAsrInputDevice('', '');
      }
      await asr.startInputPreview(provider.settings.asrInputDeviceId);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法读取麦克风设备：$error')));
      return;
    }
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AnimatedBuilder(
        animation: asr,
        builder: (context, _) => AlertDialog(
          title: const Text('选择麦克风'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 480),
            child: RadioGroup<String>(
              groupValue: provider.settings.asrInputDeviceId,
              onChanged: (id) async {
                if (id == null) return;
                InputDevice? device;
                for (final item in devices) {
                  if (item.id == id) {
                    device = item;
                    break;
                  }
                }
                final label = id.isEmpty
                    ? ''
                    : (device?.label.isNotEmpty == true ? device!.label : id);
                await _selectInputDevice(
                  dialogContext,
                  provider,
                  asr,
                  id,
                  label,
                );
              },
              child: ListView(
                shrinkWrap: true,
                children: [
                  _buildInputDeviceTile(
                    context: dialogContext,
                    provider: provider,
                    asr: asr,
                    id: '',
                    label: '系统默认设备',
                  ),
                  ...devices.map(
                    (device) => _buildInputDeviceTile(
                      context: dialogContext,
                      provider: provider,
                      asr: asr,
                      id: device.id,
                      label: device.label.isEmpty ? device.id : device.label,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
    await asr.stopInputPreview();
  }

  static Widget _buildInputDeviceTile({
    required BuildContext context,
    required SettingsProvider provider,
    required AsrService asr,
    required String id,
    required String label,
  }) {
    final selected = provider.settings.asrInputDeviceId == id;
    final previewing = asr.previewDeviceId == id;
    final level = previewing ? (asr.previewRms * 8).clamp(0.0, 1.0) : 0.0;
    return ListTile(
      leading: Radio<String>(value: id),
      title: Text(label),
      subtitle: previewing
          ? LinearProgressIndicator(value: level, minHeight: 6)
          : const Text('点击试听'),
      selected: selected,
      onTap: () async {
        await _selectInputDevice(
          context,
          provider,
          asr,
          id,
          id.isEmpty ? '' : label,
        );
      },
    );
  }

  static Future<void> _selectInputDevice(
    BuildContext context,
    SettingsProvider provider,
    AsrService asr,
    String id,
    String label,
  ) async {
    try {
      await asr.startInputPreview(id);
      await provider.setAsrInputDevice(id, label);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法使用该麦克风：$error')));
    }
  }

  static Future<void> _importAsrModel(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Sherpa-Onnx 模型包', extensions: ['zip', 'bz2', 'tbz']),
      ],
    );
    if (file == null || !context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text('正在导入模型'),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('正在验证并解压模型文件...')),
            ],
          ),
        ),
      ),
    );
    try {
      final id = await AsrService.instance.importModelArchive(file.path);
      await provider.setAsrModel(id, file.name);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('模型“${file.name}”导入完成')));
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入失败：$error')));
    }
  }

  static Future<void> _showAsrAdvancedSettings(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final settings = provider.settings;
    final mirrorController = TextEditingController(text: settings.asrMirrorUrl);
    final threadsController = TextEditingController(
      text: settings.asrNumThreads.toString(),
    );
    final rule1Controller = TextEditingController(
      text: settings.asrRule1MinTrailingSilence.toString(),
    );
    final rule2Controller = TextEditingController(
      text: settings.asrRule2MinTrailingSilence.toString(),
    );
    final rule3Controller = TextEditingController(
      text: settings.asrRule3MinUtteranceLength.toString(),
    );
    var useSystemProxy = settings.asrUseSystemProxy;
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('下载与高级设置'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('使用系统代理下载'),
                    subtitle: const Text('读取操作系统环境中的 HTTP/HTTPS 代理设置'),
                    value: useSystemProxy,
                    onChanged: (value) {
                      setModalState(() => useSystemProxy = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: mirrorController,
                    decoration: const InputDecoration(
                      labelText: '自定义下载镜像',
                      hintText: '留空使用模型原始下载地址',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: threadsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '识别线程数',
                      helperText: '0 表示根据处理器核心数自动选择',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rule1Controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '规则 1 尾部静音（秒）',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rule2Controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '规则 2 尾部静音（秒）',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rule3Controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '规则 3 最长语句（秒）',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (shouldSave == true) {
      await provider.setAsrMirrorUrl(mirrorController.text.trim());
      await provider.setAsrAdvancedParameters(
        numThreads: int.tryParse(threadsController.text.trim()) ?? 0,
        rule1MinTrailingSilence:
            double.tryParse(rule1Controller.text.trim()) ?? 2.4,
        rule2MinTrailingSilence:
            double.tryParse(rule2Controller.text.trim()) ?? 1.2,
        rule3MinUtteranceLength:
            double.tryParse(rule3Controller.text.trim()) ?? 20,
        useSystemProxy: useSystemProxy,
      );
    }
    mirrorController.dispose();
    threadsController.dispose();
    rule1Controller.dispose();
    rule2Controller.dispose();
    rule3Controller.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // 服务连接
  // ═══════════════════════════════════════════════════════

  Widget _buildBackendSection(
    BuildContext context,
    ConnectionProvider connection,
  ) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return Column(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.wifi),
              title: const Text('允许局域网连接'),
              subtitle: Text(
                settingsProvider.settings.isLanPublished
                    ? '服务端可被局域网访问'
                    : '仅本机使用',
              ),
              value: settingsProvider.settings.isLanPublished,
              onChanged: (value) {
                settingsProvider.setLanPublished(value);
              },
            ),

            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text(
                '服务端连接信息',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(connection.connectionInfoText),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showConnectionInfoDialog(context, connection),
            ),

            ListTile(
              leading: const Icon(Icons.devices),
              title: const Text('已连接客户端'),
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
        title: const Text(
          '服务端连接信息',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SelectableText(
            connection.connectionDetailBodyText,
            style: const TextStyle(height: 1.45),
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

  /// 已连接设备对话框
  void _showDevicesDialog(BuildContext context, ConnectionProvider connection) {
    final remoteDeviceIds = connection.remoteDeviceIds;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('已连接客户端'),
        content: SizedBox(
          width: 300,
          child: connection.deviceCount == 0
              ? Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      '暂无其他客户端连接',
                      style: TextStyle(color: AppColors.textMutedFor(ctx)),
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
                      subtitle: const Text('本机客户端'),
                      dense: true,
                    ),
                    if (remoteDeviceIds.isNotEmpty) const Divider(),
                    ...remoteDeviceIds.map(
                      (deviceId) => ListTile(
                        leading: const Icon(Icons.devices_other, size: 20),
                        title: Text(deviceId),
                        subtitle: const Text('客户端'),
                        dense: true,
                      ),
                    ),
                    if (remoteDeviceIds.isEmpty && connection.deviceCount <= 1)
                      const ListTile(
                        leading: Icon(Icons.info_outline, size: 20),
                        title: Text('暂无传入连接'),
                        subtitle: Text('当前设备'),
                        dense: true,
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
}
