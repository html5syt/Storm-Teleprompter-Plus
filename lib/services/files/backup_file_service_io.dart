import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../../models/app_backup.dart';

/// 原生平台上的备份文件读写服务。
///
/// 数据格式的解析和校验由 [AppBackup] 负责，本服务只处理系统文件选择器与磁盘
/// I/O，避免 UI 和后端散落 JSON 编解码逻辑。
class BackupFileService {
  static const _backupFileTypes = [
    XTypeGroup(label: '飓风提词器备份', extensions: ['json']),
  ];

  Future<bool> save(AppBackup backup) async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final location = await getSaveLocation(
      suggestedName: 'storm-teleprompter-backup-$date.json',
      acceptedTypeGroups: _backupFileTypes,
    );
    if (location == null) return false;
    await File(location.path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(backup.toJson()),
      flush: true,
    );
    return true;
  }

  Future<AppBackup?> open() async {
    final file = await openFile(acceptedTypeGroups: _backupFileTypes);
    if (file == null) return null;
    final decoded = jsonDecode(await File(file.path).readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份文件内容无效');
    }
    return AppBackup.fromJson(decoded);
  }
}
