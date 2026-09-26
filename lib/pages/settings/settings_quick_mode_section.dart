part of '../settings_page.dart';

/// 设置页中的快速模式配置区域
extension _SettingsQuickModeSection on SettingsPage {
  /// 构建快速模式设置项
  Widget _buildQuickModeSection(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    final folderProvider = Provider.of<FolderProvider?>(context);
    final defaultFolderId = settings.quickModeDefaultFolderId;
    String folderLabel = '根目录';
    if (defaultFolderId != null && folderProvider != null) {
      final folder = folderProvider.getFolderById(defaultFolderId);
      folderLabel = folder != null ? folder.name : '根目录';
    }

    return Column(
      children: [
        SwitchListTile(
          title: const Text('快速模式'),
          subtitle: const Text('启动时直接打开新稿件编辑器'),
          value: settings.quickModeEnabled,
          onChanged: (value) => provider.setQuickModeEnabled(value),
        ),
        if (settings.quickModeEnabled) ...[
          SwitchListTile(
            title: const Text('自动保存'),
            subtitle: const Text('快速模式下自动保存新建稿件'),
            value: settings.quickModeAutosave,
            onChanged: (value) => provider.setQuickModeAutosave(value),
          ),
          if (settings.quickModeAutosave)
            ListTile(
              title: const Text('默认保存位置'),
              subtitle: Text(folderLabel),
              trailing: const Icon(Icons.chevron_right),
              onTap: folderProvider == null
                  ? null
                  : () => _showQuickModeFolderPicker(
                      context,
                      provider,
                      folderProvider,
                      settings.quickModeDefaultFolderId,
                    ),
            ),
        ],
      ],
    );
  }

  /// 选择默认保存文件夹对话框
  Future<void> _showQuickModeFolderPicker(
    BuildContext context,
    SettingsProvider provider,
    FolderProvider folderProvider,
    String? currentFolderId,
  ) async {
    final selectedFolderId = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('选择默认保存位置'),
          content: SizedBox(
            width: 380,
            height: 360,
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.home, size: 20),
                  title: const Text('根目录'),
                  trailing: currentFolderId == null
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  dense: true,
                  onTap: () => Navigator.pop(dialogContext, null),
                ),
                for (final folder in folderProvider.folders)
                  ListTile(
                    leading: const Icon(Icons.folder, size: 20),
                    title: Text(
                      _formatFolderPath(folder, folderProvider),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: currentFolderId == folder.id
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    dense: true,
                    onTap: () => Navigator.pop(dialogContext, folder.id),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    // 用户选择了目录（包括选根目录 null），如果点击取消则不会触发设置
    if (selectedFolderId != currentFolderId) {
      await provider.setQuickModeDefaultFolderId(selectedFolderId);
    }
  }

  /// 格式化文件夹路径显示
  String _formatFolderPath(Folder folder, FolderProvider folderProvider) {
    final breadcrumb = folderProvider.getBreadcrumbFrom(folder.id);
    if (breadcrumb.isEmpty) return folder.name;
    return breadcrumb.map((f) => f.name).join(' / ');
  }
}
