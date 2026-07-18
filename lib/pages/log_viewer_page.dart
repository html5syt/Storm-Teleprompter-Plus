import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_log_export_service.dart';
import '../services/system/app_log_service.dart';
import '../theme/app_colors.dart';

class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  final TextEditingController _searchController = TextEditingController();
  final AppLogExportService _exportService = AppLogExportService();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
          appBar: AppBar(
            title: const Text('应用日志'),
            actions: [
              IconButton(
                tooltip: '清空日志',
                onPressed: _confirmClear,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
              IconButton(
                tooltip: '导出日志',
                onPressed: () => unawaited(_exportLogs()),
                icon: const Icon(Icons.file_download_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索日志',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除搜索',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<List<AppLogEntry>>(
                  valueListenable: AppLogService.instance.entries,
                  builder: (context, entries, _) {
                    final query = _query.toLowerCase();
                    final visible = query.isEmpty
                        ? entries
                        : entries
                              .where(
                                (entry) =>
                                    entry.line.toLowerCase().contains(query),
                              )
                              .toList(growable: false);
                    if (visible.isEmpty) {
                      return Center(
                        child: Text(query.isEmpty ? '暂无日志' : '没有匹配的日志'),
                      );
                    }
                    return SelectionArea(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: visible.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            visible[index].line,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportLogs() async {
    final text = AppLogService.instance.exportText();
    if (text.isEmpty) {
      _showMessage('暂无可导出的日志');
      return;
    }
    try {
      final saved = await _exportService.save(text);
      if (mounted && saved) _showMessage('日志已导出');
    } catch (error) {
      if (mounted) _showMessage('导出失败：$error');
    }
  }

  void _confirmClear() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空日志'),
        content: const Text('确定要清空当前应用日志吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              AppLogService.instance.clear();
              Navigator.pop(dialogContext);
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
