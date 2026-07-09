import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../models/article.dart';

class ExportResult {
  final int count;
  final String? message;

  const ExportResult({required this.count, this.message});
}

class ExportService {
  Future<ExportResult> exportArticles(List<Article> articles) async {
    if (articles.isEmpty) {
      return const ExportResult(count: 0, message: '没有可导出的稿件');
    }
    final targetDirectory = await getDirectoryPath(
      confirmButtonText: '导出到此文件夹',
    );
    if (targetDirectory == null || targetDirectory.isEmpty) {
      return const ExportResult(count: 0);
    }

    final root = Directory(targetDirectory);
    if (!await root.exists()) await root.create(recursive: true);

    var exported = 0;
    for (final article in articles) {
      final file = File(
        '${root.path}${Platform.pathSeparator}${_safeFileName(article.title)}.html',
      );
      await file.writeAsString(article.content, flush: true);
      exported++;
    }
    return ExportResult(count: exported);
  }

  String _safeFileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? '未命名稿件' : cleaned;
  }
}
