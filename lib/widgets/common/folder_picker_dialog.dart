import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/folder_provider.dart';
import 'settled_dialog.dart';

/// 目录选择结果；使用对象区分“根目录”和取消操作。
class FolderSelection {
  final String? id;
  const FolderSelection(this.id);
}

/// 返回完整目录路径，已删除的目录回退到根目录。
String folderLabel(FolderProvider provider, String? id) {
  final path = provider.getBreadcrumbFrom(id);
  return path.isEmpty ? '根目录' : '根目录 / ${path.map((f) => f.name).join(' / ')}';
}

/// 保存和设置共用的目录选择器，不改变稿件管理器的导航位置。
Future<FolderSelection?> showFolderPicker(BuildContext context) {
  final provider = context.read<FolderProvider>();
  return showSettledDialog<FolderSelection>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('选择保存位置'),
      content: SizedBox(
        width: 420,
        height: 320,
        child: ListView(
          children: [
            for (final id in <String?>[
              null,
              ...provider.folders.map((f) => f.id),
            ])
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(folderLabel(provider, id)),
                onTap: () => Navigator.pop(context, FolderSelection(id)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    ),
  );
}
