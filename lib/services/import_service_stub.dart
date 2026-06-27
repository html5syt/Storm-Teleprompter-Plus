class ImportedArticleDraft {
  final String title;
  final String content;

  const ImportedArticleDraft({required this.title, required this.content});
}

class ImportService {
  Future<ImportedArticleDraft?> importFile(String path) async {
    return null;
  }
}
