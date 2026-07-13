import 'import_batch.dart';

/// 不支持本地文件系统的平台占位导入服务。
class ImportService {
  Future<ImportedArticleDraft?> importFile(String path) async {
    return null;
  }

  Future<ImportBatchDraft> importPaths(List<String> paths) async {
    return const ImportBatchDraft();
  }
}
