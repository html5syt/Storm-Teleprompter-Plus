import 'dart:io';

import 'package:file_selector/file_selector.dart';

class AppLogExportService {
  static const _logFileTypes = [
    XTypeGroup(label: '应用日志', extensions: ['log', 'txt']),
  ];

  Future<bool> save(String content) async {
    final now = DateTime.now();
    String two(int number) => number.toString().padLeft(2, '0');
    final suggestedName =
        'storm-teleprompter-'
        '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}.log';
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: _logFileTypes,
    );
    if (location == null) return false;
    await File(location.path).writeAsString(content, flush: true);
    return true;
  }
}
