import '../../models/article.dart';
import '../../models/folder.dart';

class ExportResult {
  final int count;
  final int folderCount;
  final String? message;

  const ExportResult({required this.count, this.folderCount = 0, this.message});
}

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
