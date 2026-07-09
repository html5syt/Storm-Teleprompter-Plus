import '../models/article.dart';

class ExportResult {
  final int count;
  final String? message;

  const ExportResult({required this.count, this.message});
}

class ExportService {
  Future<ExportResult> exportArticles(List<Article> articles) async {
    return const ExportResult(count: 0, message: '当前平台暂不支持导出到本地文件夹');
  }
}
