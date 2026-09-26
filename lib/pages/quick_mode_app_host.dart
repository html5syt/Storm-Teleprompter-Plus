import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/settings_provider.dart';
import '../services/quick_mode_controller.dart';
import 'editor_page.dart';
import 'home_page.dart';

/// 快速模式根容器页面
///
/// 启动时展示新稿件编辑器，并在右下角放置浮动按钮切换到稿件管理视图。
class QuickModeAppHost extends StatefulWidget {
  const QuickModeAppHost({super.key});

  @override
  State<QuickModeAppHost> createState() => _QuickModeAppHostState();
}

class _QuickModeAppHostState extends State<QuickModeAppHost>
    with WindowListener {
  /// 0: 编辑器, 1: 稿件管理
  int _currentIndex = 0;
  final GlobalKey<EditorPageState> _editorKey = GlobalKey<EditorPageState>();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    // 初始化 QuickModeController
    QuickModeController.instance.startSession(
      onReturnToEditor: () {
        if (mounted) setState(() => _currentIndex = 0);
      },
      onSave: () async {
        final editorState = _editorKey.currentState;
        if (editorState != null) {
          final article = await editorState.promptSaveAndChooseLocation(
            context,
          );
          return article != null;
        }
        return false;
      },
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    unawaited(_handleWindowClose());
  }

  /// 窗口关闭守卫
  Future<void> _handleWindowClose() async {
    final quickMode = QuickModeController.instance;
    if (quickMode.isActive && quickMode.hasUnsavedChanges) {
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('提示'),
          content: const Text('稿件尚未保存，是否保存后退出？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('不保存'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('保存'),
            ),
          ],
        ),
      );

      if (choice == null || choice == 'cancel') return;
      if (choice == 'save') {
        final success = await quickMode.triggerSave();
        if (!success) return;
      }
    }

    // 允许关闭
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;

    return IndexedStack(
      index: _currentIndex,
      children: [
        Scaffold(
          body: EditorPage(
            key: _editorKey,
            isQuickMode: true,
            quickModeAutosave: settings.quickModeAutosave,
            initialFolderId: settings.quickModeDefaultFolderId,
            onOpenManageView: () {
              setState(() => _currentIndex = 1);
            },
          ),
        ),
        const HomePage(),
      ],
    );
  }
}
