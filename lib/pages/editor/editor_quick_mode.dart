part of '../editor_page.dart';

/// 快速草稿的显式保存和离开保护，不把浏览稿件列表当作离开。
mixin EditorQuickMode on State<EditorPage>, EditorLogic {
  final _leaveAction = SingleFlightAction<bool>();
  final _manualSaveAction = SingleFlightAction<bool>();

  /// 显式保存允许选择位置，已有稿件复用原记录而不是创建副本。
  Future<bool> manualSave() => _manualSaveAction.run(_manualSave);

  /// 目录选择与落盘属于同一保存事务，连续点击不会创建多份稿件。
  Future<bool> _manualSave() async {
    final target = await showFolderPicker(context);
    if (target == null || !mounted) return false;
    _saveFolderId = target.id;
    await save(force: true);
    if (!mounted) return false;
    var succeeded = !isDirty;
    final article = _savedArticle;
    if (succeeded && article != null && article.folderId != target.id) {
      succeeded = await _articleProvider.moveArticleToFolder(
        article.id,
        target.id,
      );
      if (succeeded)
        _savedArticle = article.copyWith(
          folderId: target.id,
          clearFolderId: target.id == null,
        );
    }
    if (!mounted) return false;
    if (!succeeded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
    }
    return succeeded;
  }

  /// 所有离开入口共用一次确认，避免窗口关闭和返回键重复弹窗。
  Future<bool> confirmLeave() => _leaveAction.run(_confirmLeave);

  /// 自动保存先刷盘；任何失败或取消都保留当前草稿。
  Future<bool> _confirmLeave() async {
    // 若用户已点保存，退出等待同一个目录选择结果，不再另开保存提示。
    final pendingSave = _manualSaveAction.pending;
    if (pendingSave != null) return await pendingSave && mounted && !isDirty;
    _autosaveTimer?.cancel();
    if (autoSaveEnabled && (isDirty || isSaving)) await save(force: true);
    if (!mounted) return false;
    if (!isDirty) return true;
    final draftTitle = _effectiveTitle(_captureDraft());
    final draftKind = widget.quickMode ? '临时稿件' : '稿件';
    final choice = await showSettledDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('保存$draftKind？'),
        content: Text('$draftKind“$draftTitle”尚未保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('不保存'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (choice == 'discard') {
      // 销毁编辑器时不能再触发原有的自动保存兜底。
      _discardOnDispose = true;
      return true;
    }
    if (choice != 'save') return false;
    return manualSave();
  }

  /// 嵌入首页时交给首页执行退出流程，普通路由仍使用返回操作。
  Future<void> requestExit() async {
    if (widget.onExit != null) {
      await widget.onExit!();
      return;
    }
    if (!await confirmLeave() || !mounted) return;
    Navigator.of(context).pop();
  }
}
