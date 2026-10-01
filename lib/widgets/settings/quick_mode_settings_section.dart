import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/folder_provider.dart';
import '../../providers/settings_provider.dart';
import '../common/folder_picker_dialog.dart';

/// 快速模式的全局开关、自动保存策略和默认目录。
class QuickModeSettingsSection extends StatelessWidget {
  const QuickModeSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final settings = provider.settings;
    final folders = context.watch<FolderProvider>();
    return Column(
      children: [
        SwitchListTile(
          title: const Text('快速模式'),
          value: settings.quickModeEnabled,
          onChanged: (value) => provider.setQuickMode(enabled: value),
        ),
        SwitchListTile(
          title: const Text('自动保存'),
          value: settings.quickModeAutoSave,
          onChanged: settings.quickModeEnabled
              ? (value) => provider.setQuickMode(autoSave: value)
              : null,
        ),
        ListTile(
          title: const Text('默认保存位置'),
          subtitle: Text(folderLabel(folders, settings.quickModeFolderId)),
          trailing: const Icon(Icons.chevron_right),
          enabled: settings.quickModeEnabled && settings.quickModeAutoSave,
          onTap: () async {
            final target = await showFolderPicker(context);
            if (target != null)
              await provider.setQuickMode(folderId: target.id ?? '');
          },
        ),
      ],
    );
  }
}
