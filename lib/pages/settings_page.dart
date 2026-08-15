import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../models/app_backup.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/article_provider.dart';
import '../providers/folder_provider.dart';
import '../backend/ws_protocol.dart';
import '../services/asr_service.dart';
import '../services/backup_file_service.dart';
import '../services/font_service.dart';
import '../services/selected_file_cleanup.dart';
import '../theme/app_colors.dart';
import '../widgets/common/app_color_picker_dialog.dart';
import '../widgets/settings/about_settings_section.dart';

part 'settings/settings_asr_advanced_dialog.dart';
part 'settings/settings_backup_section.dart';

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
                  _buildSectionHeader(context, '应用主题'),
                  const SizedBox(height: 12),
                  _buildThemeColorTile(context, provider, settings),
                  _buildBrightnessModeTile(context, provider, settings),

                  const SizedBox(height: 24),

                  _buildSectionHeader(context, '应用字体'),
                  const SizedBox(height: 12),
                  _buildFontFamilyTile(context, provider, settings),

                  const SizedBox(height: 24),

                  if (!connection.isRemote && !kIsWeb) ...[
                    _buildSectionHeader(context, '语音识别模型'),
                    const SizedBox(height: 12),
                    _buildAsrSection(context, provider, settings),
                    const SizedBox(height: 24),
                  ],

                  if (!connection.isRemote) ...[
                    _buildSectionHeader(context, '服务连接'),
                    const SizedBox(height: 12),
                    _buildBackendSection(context, connection),
                    const SizedBox(height: 24),
                  ],

                  if (!kIsWeb) ...[
                    _buildSectionHeader(context, '备份与恢复'),
                    const SizedBox(height: 12),
                    _buildBackupSection(context, connection),
                    const SizedBox(height: 24),
                  ],

                  _buildSectionHeader(context, '重置'),
                  const SizedBox(height: 12),
                  _buildResetSection(context, provider),

                  const SizedBox(height: 24),

                  _buildSectionHeader(context, '关于'),
                  const SizedBox(height: 12),
                  const AboutSettingsSection(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }


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

  Future<void> _showColorPicker(
    BuildContext context, {
    required Color currentColor,
    required ValueChanged<Color> onColorSelected,
  }) async {
    final selected = await AppColorPickerDialog.show(
      context,
      title: '选择颜色',
      currentColor: currentColor,
    );
    if (selected != null) onColorSelected(selected);
  }


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
    var models = await asr.listAvailableModels();
    var downloadedModelIds = <String>{};
    final downloadedStates = await Future.wait(
      models.map((model) => asr.isModelDownloaded(model.id)),
    );
    for (var index = 0; index < models.length; index++) {
      if (downloadedStates[index]) downloadedModelIds.add(models[index].id);
    }

    var currentModelId = provider.settings.asrModelId;
    if (currentModelId.isNotEmpty &&
        !downloadedModelIds.contains(currentModelId)) {
      await provider.clearAsrModel();
      currentModelId = '';
    }
    if (!context.mounted) return;
    final recommendedModelId = asr.recommendModel().id;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => AnimatedBuilder(
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: models.length,
                      itemBuilder: (ctx, index) {
                        final model = models[index];
                        final isSelected = model.id == currentModelId;
                        final progress = asr.getDownloadProgress(model.id);
                        final anyDownloading = asr.allDownloadProgress.values
                            .any((item) => item.isDownloading);
                        final isDownloaded =
                            downloadedModelIds.contains(model.id) ||
                            progress.isCompleted;
                        final modelDetails = model.isImported
                            ? '${model.languages} · ${model.scenario}'
                                  '${model.approximateSizeMB > 0 ? ' · 约 ${model.approximateSizeMB} MB' : ''}'
                            : '${model.languages} · ${model.scenario}\n'
                                  '准确率 ${model.accuracy} · 延迟 ${model.latency} · '
                                  '约 ${model.approximateSizeMB} MB · '
                                  '建议内存 ${model.recommendedMemoryMB} MB';

                        return InkWell(
                          onTap: isSelected || !isDownloaded
                              ? null
                              : () async {
                                  await provider.setAsrModel(
                                    model.id,
                                    model.name,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
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
                                        modelDetails,
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
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ],
                                      if (isDownloaded)
                                        Text(
                                          model.isImported ? '已导入' : '已下载',
                                          style: const TextStyle(
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
                                        !progress.isDownloading &&
                                        !model.isImported)
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
                                                if (!ctx.mounted) return;
                                                if (await asr.isModelDownloaded(
                                                  model.id,
                                                )) {
                                                  setSheetState(
                                                    () => downloadedModelIds
                                                        .add(model.id),
                                                  );
                                                }
                                              },
                                      ),
                                    if (isDownloaded &&
                                        !progress.isDownloading &&
                                        !model.isImported)
                                      IconButton(
                                        icon: const Icon(Icons.refresh),
                                        tooltip: '重新下载或更新',
                                        onPressed: anyDownloading
                                            ? null
                                            : () => _downloadAsrModel(
                                                ctx,
                                                asr,
                                                provider,
                                                model,
                                              ),
                                      ),
                                    if (isDownloaded && !progress.isDownloading)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: '删除模型文件',
                                        onPressed: anyDownloading
                                            ? null
                                            : () async {
                                                if (!await _confirmDeleteAsrModel(
                                                  ctx,
                                                  model,
                                                )) {
                                                  return;
                                                }
                                                await asr.deleteModel(model.id);
                                                if (currentModelId ==
                                                    model.id) {
                                                  await provider
                                                      .clearAsrModel();
                                                  currentModelId = '';
                                                }
                                                models = await asr
                                                    .listAvailableModels();
                                                downloadedModelIds = {
                                                  for (final item in models)
                                                    if (await asr
                                                        .isModelDownloaded(
                                                          item.id,
                                                        ))
                                                      item.id,
                                                };
                                                if (ctx.mounted) {
                                                  setSheetState(() {});
                                                }
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

  static Future<bool> _confirmDeleteAsrModel(
    BuildContext context,
    AsrModelInfo model,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除模型'),
            content: Text('确定删除“${model.name}”的全部本地模型文件吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
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
      _showMicrophoneError(context, asr, '无法读取麦克风设备：$error');
      return;
    }
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AnimatedBuilder(
        animation: asr,
        builder: (context, _) => AlertDialog(
          title: const Text('选择麦克风'),
          content: SizedBox(
            width: 520,
            height: (MediaQuery.sizeOf(dialogContext).height * 0.6).clamp(
              220.0,
              480.0,
            ),
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
                children: [
                  if (defaultTargetPlatform == TargetPlatform.windows)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        'Windows 桌面应用不会弹出麦克风授权框。若试听失败，请检查系统“麦克风隐私设置”中的桌面应用访问权限。',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
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
    final previewError = previewing ? asr.previewError : null;
    return ListTile(
      leading: Radio<String>(value: id),
      title: Text(label),
      subtitle: previewError != null
          ? Text(previewError, style: const TextStyle(color: AppColors.error))
          : previewing
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
      _showMicrophoneError(context, asr, '无法使用该麦克风：$error');
    }
  }

  static void _showMicrophoneError(
    BuildContext context,
    AsrService asr,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: defaultTargetPlatform == TargetPlatform.windows
            ? SnackBarAction(
                label: '打开系统设置',
                onPressed: () {
                  unawaited(asr.openMicrophonePrivacySettings());
                },
              )
            : null,
      ),
    );
  }

  static Future<void> _importAsrModel(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Sherpa-Onnx 模型包',
          extensions: ['zip', 'bz2', 'tbz'],
          mimeTypes: [
            'application/zip',
            'application/x-bzip2',
            'application/x-bzip',
          ],
        ),
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
      final asr = AsrService.instance;
      final id = await asr.importModelArchive(
        file.path,
        archiveName: file.name,
      );
      final models = await asr.listAvailableModels();
      var importedName = file.name;
      for (final model in models) {
        if (model.id == id) {
          importedName = model.name;
          break;
        }
      }
      await provider.setAsrModel(id, importedName);
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
    } finally {
      await cleanupTemporarySelectedFile(file.path);
    }
  }

  static Future<void> _showAsrAdvancedSettings(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final result = await showDialog<_AsrAdvancedSettingsResult>(
      context: context,
      builder: (_) => _AsrAdvancedSettingsDialog(settings: provider.settings),
    );
    if (result != null) {
      await provider.setAsrMirrorUrl(result.mirrorUrl);
      await provider.setAsrAdvancedParameters(
        numThreads: result.numThreads,
        rule1MinTrailingSilence: result.rule1MinTrailingSilence,
        rule2MinTrailingSilence: result.rule2MinTrailingSilence,
        rule3MinUtteranceLength: result.rule3MinUtteranceLength,
        useSystemProxy: result.useSystemProxy,
      );
    }
  }


  Widget _buildBackendSection(
    BuildContext context,
    ConnectionProvider connection,
  ) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text(
            '服务端连接信息',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
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
  }

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
                    ListTile(
                      leading: const Icon(Icons.computer, size: 20),
                      title: Text('本机 (${connection.clientId ?? "未知"})'),
                      dense: true,
                    ),
                    if (remoteDeviceIds.isNotEmpty) const Divider(),
                    ...remoteDeviceIds.map(
                      (deviceId) => ListTile(
                        leading: const Icon(Icons.devices_other, size: 20),
                        title: Text(deviceId),
                        dense: true,
                      ),
                    ),
                    if (remoteDeviceIds.isEmpty && connection.deviceCount <= 1)
                      const ListTile(
                        leading: Icon(Icons.info_outline, size: 20),
                        title: Text('暂无传入连接'),
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
