part of 'settings_page.dart';

/// 设置页中的完整备份区域。
///
/// 文件选择和 JSON 读写由 [BackupFileService] 负责，服务端数据读写通过
/// [ConnectionProvider] 统一请求，页面只处理用户确认、状态刷新和结果提示。
extension _SettingsBackupSection on SettingsPage {
  Widget _buildBackupSection(
    BuildContext context,
    ConnectionProvider connection,
  ) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: const Text('导出完整备份'),
          subtitle: const Text('包含全部稿件、文件夹和应用设置'),
          onTap: connection.isConnected
              ? () => _exportBackup(context, connection)
              : null,
        ),
        ListTile(
          leading: const Icon(Icons.restore_outlined),
          title: const Text('从备份恢复'),
          subtitle: const Text('使用备份内容替换当前全部数据'),
          onTap: connection.isConnected
              ? () => _restoreBackup(context, connection)
              : null,
        ),
      ],
    );
  }

  Future<void> _exportBackup(
    BuildContext context,
    ConnectionProvider connection,
  ) async {
    try {
      final response = await connection.request(WsMessageType.appBackupExport);
      if (response.type != WsMessageType.appBackupExportResponse) {
        throw Exception(response.data['message'] ?? '服务端未返回备份数据');
      }

      final backup = AppBackup.fromJson(response.data);
      final saved = await BackupFileService().save(backup);
      if (saved && context.mounted) {
        _showBackupMessage(context, '完整备份已导出');
      }
    } catch (error) {
      if (context.mounted) _showBackupMessage(context, '导出备份失败：$error');
    }
  }

  Future<void> _restoreBackup(
    BuildContext context,
    ConnectionProvider connection,
  ) async {
    try {
      final backup = await BackupFileService().open();
      if (backup == null || !context.mounted) return;
      if (!await _confirmBackupRestore(context) || !context.mounted) return;

      final response = await connection.request(
        WsMessageType.appBackupRestore,
        data: backup.toJson(),
      );
      if (response.type != WsMessageType.appBackupRestoreResponse) {
        throw Exception(response.data['message'] ?? '服务端拒绝恢复备份');
      }

      await _reloadRestoredData(context);
      if (context.mounted) _showBackupMessage(context, '备份已恢复');
    } catch (error) {
      if (context.mounted) _showBackupMessage(context, '恢复备份失败：$error');
    }
  }

  Future<bool> _confirmBackupRestore(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('恢复完整备份'),
            content: const Text('当前服务端的全部稿件、文件夹和设置将被备份内容替换。此操作无法撤销。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('恢复'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _reloadRestoredData(BuildContext context) {
    return Future.wait([
      context.read<ArticleProvider>().loadArticles(),
      context.read<FolderProvider>().loadFolders(),
      context.read<SettingsProvider>().loadSettings(),
    ]);
  }

  void _showBackupMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
