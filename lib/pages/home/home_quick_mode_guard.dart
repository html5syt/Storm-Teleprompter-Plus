part of '../home_page.dart';

/// 首页中快速模式与稿件切换守卫相关逻辑
extension _HomeQuickModeGuard on _HomePageState {
  /// 在快速模式下选择其他稿件时执行切换确认与清理
  Future<bool> _checkQuickModeBeforeSelectArticle(Article targetArticle) async {
    final quickMode = QuickModeController.instance;
    if (!quickMode.isActive) return true;

    // 如果未保存，询问用户是否保存
    if (quickMode.hasUnsavedChanges) {
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('提示'),
          content: const Text('临时稿件尚未保存，是否保存？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('不保存'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('保存'),
            ),
          ],
        ),
      );

      if (choice == null || choice == 'cancel') {
        return false;
      }

      if (choice == 'save') {
        final success = await quickMode.triggerSave();
        if (!success) {
          // 保存失败或用户在保存文件对话框中取消
          return false;
        }
      }
    }

    // 关闭临时稿件，退出本次快速模式，之后行为和普通模式相同
    quickMode.exitSession();
    return true;
  }
}
