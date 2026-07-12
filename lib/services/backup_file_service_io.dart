import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

class BackupFileService {
  Future<bool> save(Map<String, dynamic> data) async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final location = await getSaveLocation(
      suggestedName: 'storm-teleprompter-backup-$date.json',
      acceptedTypeGroups: const [
        XTypeGroup(label: '飓风提词器备份', extensions: ['json']),
      ],
    );
    if (location == null) return false;
    await File(location.path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    return true;
  }

  Future<Map<String, dynamic>?> open() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: '飓风提词器备份', extensions: ['json']),
      ],
    );
    if (file == null) return null;
    final decoded = jsonDecode(await File(file.path).readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份文件内容无效');
    }
    return decoded;
  }
}
