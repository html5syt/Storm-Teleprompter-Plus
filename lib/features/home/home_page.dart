import 'package:flutter/material.dart';

import '../../core/controllers/teleprompter_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/model_downloader.dart';
import '../../core/services/model_downloader_factory.dart';
import '../editor/script_editor_page.dart';
import '../teleprompter/teleprompter_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final TeleprompterController _controller;
  late final ModelDownloader _downloader;
  final TextEditingController _searchController = TextEditingController();

  bool _hideSidebars = false;

  @override
  void initState() {
    super.initState();
    _controller = TeleprompterController();
    _downloader = createModelDownloader();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openEditor([String? scriptId]) async {
    final targetId =
        scriptId ??
        _controller.selectedScriptId ??
        (await _controller.createScript()).id;
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ScriptEditorPage(controller: _controller, scriptId: targetId),
      ),
    );
  }

  Future<void> _openModelManager() async {
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ModelManagerSheet(controller: _controller, downloader: _downloader),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: _hideSidebars
              ? null
              : AppBar(
                  title: const Text('Storm Teleprompter Plus'),
                  actions: <Widget>[
                    IconButton(
                      tooltip: '隐藏边栏并全屏',
                      onPressed: () {
                        setState(() {
                          _hideSidebars = true;
                        });
                      },
                      icon: const Icon(Icons.fullscreen_rounded),
                    ),
                    IconButton(
                      tooltip: '模型管理',
                      onPressed: _openModelManager,
                      icon: const Icon(Icons.cloud_download_rounded),
                    ),
                    IconButton(
                      tooltip: '新建稿件',
                      onPressed: () async {
                        final script = await _controller.createScript();
                        await _openEditor(script.id);
                      },
                      icon: const Icon(Icons.add_rounded),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 1120 && !_hideSidebars) {
                return Row(
                  children: <Widget>[
                    SizedBox(
                      width: 320,
                      child: _LibraryPanel(
                        controller: _controller,
                        searchController: _searchController,
                        openEditor: _openEditor,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: TeleprompterView(controller: _controller),
                      ),
                    ),
                    SizedBox(
                      width: 360,
                      child: _InspectorPanel(
                        controller: _controller,
                        openModelManager: _openModelManager,
                      ),
                    ),
                  ],
                );
              }

              if (_hideSidebars) {
                return Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TeleprompterView(controller: _controller),
                    ),
                    Positioned(
                      top: 20,
                      right: 20,
                      child: IconButton.filledTonal(
                        onPressed: () {
                          setState(() {
                            _hideSidebars = false;
                          });
                        },
                        icon: const Icon(Icons.fullscreen_exit_rounded),
                      ),
                    ),
                  ],
                );
              }

              return DefaultTabController(
                length: 3,
                child: Column(
                  children: <Widget>[
                    const TabBar(
                      tabs: <Tab>[
                        Tab(
                          icon: Icon(Icons.library_books_rounded),
                          text: '稿件',
                        ),
                        Tab(icon: Icon(Icons.subtitles_rounded), text: '提词'),
                        Tab(icon: Icon(Icons.tune_rounded), text: '设置'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: <Widget>[
                          _LibraryPanel(
                            controller: _controller,
                            searchController: _searchController,
                            openEditor: _openEditor,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: TeleprompterView(controller: _controller),
                          ),
                          _InspectorPanel(
                            controller: _controller,
                            openModelManager: _openModelManager,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _LibraryPanel extends StatelessWidget {
  const _LibraryPanel({
    required this.controller,
    required this.searchController,
    required this.openEditor,
  });

  final TeleprompterController controller;
  final TextEditingController searchController;
  final Future<void> Function([String? scriptId]) openEditor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: searchController,
      builder: (context, _) {
        final theme = Theme.of(context);
        final query = searchController.text.trim().toLowerCase();
        final scripts = controller.scripts.where((script) {
          if (query.isEmpty) {
            return true;
          }
          return script.title.toLowerCase().contains(query) ||
              script.content.toLowerCase().contains(query);
        }).toList();

        return Card(
          margin: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    labelText: '搜索稿件',
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: scripts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final script = scripts[index];
                    final selected = script.id == controller.selectedScriptId;
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => controller.selectScript(script.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selected
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                )
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.34,
                                  )
                                : Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    script.title,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      await openEditor(script.id);
                                    } else if (value == 'delete') {
                                      await controller.deleteScript(script.id);
                                    }
                                  },
                                  itemBuilder: (_) =>
                                      const <PopupMenuEntry<String>>[
                                        PopupMenuItem<String>(
                                          value: 'edit',
                                          child: Text('编辑'),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Text('删除'),
                                        ),
                                      ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              script.content
                                  .replaceAll(RegExp(r'<[^>]+>'), '')
                                  .replaceAll('\n', ' '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: FilledButton.icon(
                  onPressed: () async {
                    final script = await controller.createScript();
                    await openEditor(script.id);
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('新建稿件'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({
    required this.controller,
    required this.openModelManager,
  });

  final TeleprompterController controller;
  final Future<void> Function() openModelManager;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '显示参数',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text('字体大小 ${controller.settings.fontSize.toStringAsFixed(0)}'),
                Slider(
                  value: controller.settings.fontSize,
                  min: 28,
                  max: 84,
                  divisions: 14,
                  onChanged: (value) => controller.setSettings(
                    controller.settings.copyWith(fontSize: value),
                  ),
                ),
                Text(
                  '滚动速度 ${controller.settings.speedWpm.toStringAsFixed(0)} 字/分',
                ),
                Slider(
                  value: controller.settings.speedWpm,
                  min: 40,
                  max: 360,
                  divisions: 32,
                  onChanged: (value) => controller.setSettings(
                    controller.settings.copyWith(speedWpm: value),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('镜像翻转'),
                  value: controller.settings.mirrorMode,
                  onChanged: (value) => controller.setSettings(
                    controller.settings.copyWith(mirrorMode: value),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('自动滚动'),
                  value: controller.settings.autoScroll,
                  onChanged: (value) => controller.setSettings(
                    controller.settings.copyWith(autoScroll: value),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('语音跟随'),
                  value: controller.settings.voiceFollow,
                  onChanged: (value) => controller.setSettings(
                    controller.settings.copyWith(voiceFollow: value),
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '模型与识别',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text('当前模型：${controller.selectedModelPackage.name}'),
                const SizedBox(height: 8),
                Text(
                  controller.status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: openModelManager,
                  icon: const Icon(Icons.cloud_download_rounded),
                  label: const Text('打开模型管理'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ModelManagerSheet extends StatefulWidget {
  const _ModelManagerSheet({
    required this.controller,
    required this.downloader,
  });

  final TeleprompterController controller;
  final ModelDownloader downloader;

  @override
  State<_ModelManagerSheet> createState() => _ModelManagerSheetState();
}

class _ModelManagerSheetState extends State<_ModelManagerSheet> {
  final Map<String, DownloadStatus> _downloadStatus =
      <String, DownloadStatus>{};
  final TextEditingController _customUrlController = TextEditingController();
  late final TextEditingController _mirrorUrlController;

  @override
  void initState() {
    super.initState();
    _customUrlController.text = widget.controller.settings.customModelUrl;
    _mirrorUrlController = TextEditingController(
      text: widget.controller.settings.customModelMirrorUrl,
    );
  }

  @override
  void dispose() {
    _customUrlController.dispose();
    _mirrorUrlController.dispose();
    super.dispose();
  }

  Future<void> _download(ModelPackage model) async {
    final ticket = await widget.downloader.prepare(model);
    final status = await widget.downloader.download(
      ticket,
      onProgress: (value) {
        setState(() {
          _downloadStatus[model.id] = value;
        });
      },
    );
    setState(() {
      _downloadStatus[model.id] = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '模型管理',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: <Widget>[
                    TextField(
                      controller: _customUrlController,
                      decoration: InputDecoration(
                        labelText: '自定义模型地址',
                        helperText: '填写可直接下载的模型压缩包 URL。',
                        suffixIcon: IconButton(
                          onPressed: () async {
                            final url = _customUrlController.text.trim();
                            if (url.isEmpty) {
                              return;
                            }
                            await widget.controller.setCustomModelConfig(
                              url: url,
                              mirrorUrl: url,
                            );
                            await widget.controller.setSelectedModel('custom');
                            _downloadStatus.remove('custom');
                            setState(() {});
                          },
                          icon: const Icon(Icons.check_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _mirrorUrlController,
                      onChanged: (value) => widget.controller
                          .setCustomModelConfig(mirrorUrl: value),
                      decoration: const InputDecoration(
                        labelText: '自定义镜像地址',
                        helperText: '可选。优先用于国内镜像加速。',
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final model in modelCatalog)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        model.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    ChoiceChip(
                                      label: const Text('选用'),
                                      selected:
                                          widget.controller.selectedModelId ==
                                          model.id,
                                      onSelected: (_) => widget.controller
                                          .setSelectedModel(model.id),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(model.description),
                                const SizedBox(height: 8),
                                Text(
                                  '推荐设备：${model.recommendedDevice} · ${model.sizeLabel}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (model.id != 'custom')
                                  FilledButton.icon(
                                    onPressed: () => _download(model),
                                    icon: const Icon(Icons.download_rounded),
                                    label: const Text('下载到本机'),
                                  ),
                                if (model.id == 'custom')
                                  FilledButton.icon(
                                    onPressed: () async {
                                      final url = _customUrlController.text
                                          .trim();
                                      if (url.isEmpty) {
                                        return;
                                      }
                                      await widget.controller.setSelectedModel(
                                        'custom',
                                      );
                                      await _download(
                                        ModelPackage(
                                          id: 'custom',
                                          name: '自定义模型',
                                          description: '用户输入的自定义模型。',
                                          fileName: 'custom-model.zip',
                                          downloadUrl: url,
                                          mirrorUrl:
                                              widget
                                                  .controller
                                                  .settings
                                                  .customModelMirrorUrl
                                                  .isEmpty
                                              ? url
                                              : widget
                                                    .controller
                                                    .settings
                                                    .customModelMirrorUrl,
                                          recommendedDevice: '按需选择',
                                          sizeLabel: '自定义',
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.download_rounded),
                                    label: const Text('下载自定义模型'),
                                  ),
                                if (_downloadStatus.containsKey(
                                  model.id,
                                )) ...<Widget>[
                                  const SizedBox(height: 10),
                                  LinearProgressIndicator(
                                    value: _downloadStatus[model.id]!.progress,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${_downloadStatus[model.id]!.message ?? '下载中'} · ${humanBytes(_downloadStatus[model.id]!.completedBytes)} / ${humanBytes(_downloadStatus[model.id]!.totalBytes)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
