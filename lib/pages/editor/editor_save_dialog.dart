part of '../editor_page.dart';

/// 编辑器保存位置选择对话框
class _EditorSaveLocationDialog extends StatefulWidget {
  final FolderProvider folderProvider;
  final String? initialFolderId;

  const _EditorSaveLocationDialog({
    required this.folderProvider,
    this.initialFolderId,
  });

  @override
  State<_EditorSaveLocationDialog> createState() =>
      _EditorSaveLocationDialogState();
}

class _EditorSaveLocationDialogState extends State<_EditorSaveLocationDialog> {
  String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.initialFolderId;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择保存位置'),
      content: SizedBox(
        width: 380,
        height: 360,
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.home, size: 20),
              title: const Text('根目录'),
              trailing: _selectedFolderId == null
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              dense: true,
              onTap: () => setState(() => _selectedFolderId = null),
            ),
            for (final folder in widget.folderProvider.folders)
              ListTile(
                leading: const Icon(Icons.folder, size: 20),
                title: Text(
                  _formatFolderPath(folder, widget.folderProvider),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: _selectedFolderId == folder.id
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                dense: true,
                onTap: () => setState(() => _selectedFolderId = folder.id),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _SaveLocationResult(_selectedFolderId)),
          child: const Text('保存'),
        ),
      ],
    );
  }

  String _formatFolderPath(Folder folder, FolderProvider folderProvider) {
    final breadcrumb = folderProvider.getBreadcrumbFrom(folder.id);
    if (breadcrumb.isEmpty) return folder.name;
    return breadcrumb.map((f) => f.name).join(' / ');
  }
}

class _SaveLocationResult {
  final String? folderId;
  const _SaveLocationResult(this.folderId);
}
