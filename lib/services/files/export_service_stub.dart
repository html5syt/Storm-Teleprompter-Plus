import '../../models/article.dart';
import '../../models/folder.dart';

/// 稿件导出结果，包含成功导出的稿件和文件夹数量。
class ExportResult {
  final int count;
  final int folderCount;
  final String? message;

  const ExportResult({required this.count, this.folderCount = 0, this.message});
}

/// 不支持目录写入的平台占位导出服务。
class ExportService {
  Future<ExportResult> exportArticles(List<Article> articles) async {
    return const ExportResult(count: 0, message: '当前平台暂不支持导出到本地文件夹');
  }

  Future<ExportResult> exportItems({
    required List<Article> articles,
    required List<Folder> folders,
    required Set<String> selectedIds,
  }) async {
    return const ExportResult(count: 0, message: '当前平台暂不支持导出到本地文件夹');
  }
}
