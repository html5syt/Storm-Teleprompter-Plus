class FontService {
  static final FontService _instance = FontService._internal();

  factory FontService() => _instance;

  FontService._internal();

  static const List<String> _fallbackFonts = [
    'Noto Sans SC',
    'Noto Serif SC',
    'Microsoft YaHei',
    'SimHei',
    'SimSun',
    'KaiTi',
    'FangSong',
    'Arial',
    'Courier New',
    'Times New Roman',
    'Georgia',
    'Consolas',
    'Calibri',
    'Segoe UI',
    'Tahoma',
    'Verdana',
  ];

  Future<List<String>> getAvailableFonts({bool refresh = false}) async {
    return _sortFonts(_fallbackFonts);
  }

  Future<List<String>> searchFonts(String query) async {
    final fonts = await getAvailableFonts();
    final lowerQuery = query.trim().toLowerCase();
    if (lowerQuery.isEmpty) return fonts;
    return fonts.where((f) => f.toLowerCase().contains(lowerQuery)).toList();
  }

  List<String> getPresetFonts() => _fallbackFonts;

  String? buildFontFamily(String fontName) {
    if (fontName.isEmpty) return null;
    return fontName;
  }

  static List<String> _sortFonts(Iterable<String> fonts) {
    final byLowercase = <String, String>{};
    for (final font in fonts) {
      final cleaned = font.trim();
      if (cleaned.isEmpty) continue;
      byLowercase.putIfAbsent(cleaned.toLowerCase(), () => cleaned);
    }
    final sorted = byLowercase.values.toList();
    sorted.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }
}
