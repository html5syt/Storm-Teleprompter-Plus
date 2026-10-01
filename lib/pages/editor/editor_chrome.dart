part of '../editor_page.dart';

/// 编辑器页头负责工作模式标识和保存操作，窄屏将操作放到第二行。
mixin EditorChrome on State<EditorPage>, EditorLogic, EditorQuickMode {
  /// 快速模式始终标识应用名称与模式，不随临时稿件保存状态变化。
  AppBar buildEditorAppBar(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 680;
    final title = widget.quickMode
        ? '${AppConstants.displayName}：快速模式'
        : (currentArticle != null ? '编辑稿件' : '新建稿件');
    final actions = _buildEditorActions(context);
    return AppBar(
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: compact ? const TextStyle(fontSize: 16) : null,
      ),
      automaticallyImplyLeading: !widget.quickMode,
      actions: compact ? null : actions,
      bottom: compact
          ? PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ),
            )
          : null,
    );
  }

  /// 保存状态与开始提词按钮在宽窄布局中共用，避免行为分叉。
  List<Widget> _buildEditorActions(BuildContext context) {
    final unsaved = isDirty || currentArticle == null;
    return [
      if (!autoSaveEnabled)
        IconButton(
          tooltip: '保存',
          onPressed: isSaving ? null : manualSave,
          icon: const Icon(Icons.save_outlined),
        ),
      Center(
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(
            '$plainTextLength 字',
            style: TextStyle(
              color: AppColors.textMutedFor(context),
              fontSize: 13,
            ),
          ),
        ),
      ),
      Center(
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(
            saveStatusText,
            style: TextStyle(
              fontSize: 12,
              color: isSaving
                  ? AppColors.warning
                  : (!autoSaveEnabled && unsaved
                        ? AppColors.error
                        : (isDirty
                              ? AppColors.textMutedFor(context)
                              : AppColors.success)),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Tooltip(
          message: '开始提词 (Ctrl+Alt+S)',
          child: FilledButton.icon(
            onPressed: canStartTeleprompter ? quickStartTeleprompter : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始提词'),
          ),
        ),
      ),
    ];
  }
}
