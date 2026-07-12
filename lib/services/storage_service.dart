import 'dart:convert';
import 'app_preferences.dart';
import '../models/article.dart';
import '../models/app_settings.dart';
import '../models/folder.dart';
import '../utils/constants.dart';

/// 本地存储服务
///
/// 使用统一应用数据存储实现稿件和设置的本地持久化。
/// 无需后端服务，单次运行即可使用。
class StorageService {
  static StorageService? _instance;
  late AppPreferences _prefs;

  StorageService._();

  /// 获取单例实例
  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      _instance!._prefs = await AppPreferences.getInstance();
    }
    return _instance!;
  }

  // ─── 稿件存储 ──────────────────────────────────────────────

  /// 获取所有稿件列表（按更新时间倒序）
  Future<List<Article>> loadArticles() async {
    final jsonStr = _prefs.getString(AppConstants.prefKeyArticles);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr) as List<dynamic>;
      final articles = jsonList
          .map((e) => Article.fromJson(e as Map<String, dynamic>))
          .toList();
      articles.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return articles;
    } catch (_) {
      return [];
    }
  }

  /// 保存全部稿件
  Future<void> saveArticles(List<Article> articles) async {
    final jsonStr = jsonEncode(articles.map((a) => a.toJson()).toList());
    await _prefs.setString(AppConstants.prefKeyArticles, jsonStr);
  }

  /// 创建新稿件
  Future<Article> createArticle({
    required String title,
    required String content,
  }) async {
    final now = DateTime.now();
    final article = Article(
      id: _generateId(),
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );

    final articles = await loadArticles();
    articles.insert(0, article);
    await saveArticles(articles);
    return article;
  }

  /// 更新稿件
  Future<Article?> updateArticle(
    String id, {
    String? title,
    String? content,
  }) async {
    final articles = await loadArticles();
    final index = articles.indexWhere((a) => a.id == id);
    if (index == -1) return null;

    final updated = articles[index].copyWith(
      title: title,
      content: content,
      updatedAt: DateTime.now(),
    );
    articles[index] = updated;
    await saveArticles(articles);
    return updated;
  }

  /// 更新稿件的提词器设置
  Future<Article?> updateArticleTeleprompterSettings(
    String id,
    Map<String, dynamic> teleprompterSettings,
  ) async {
    final articles = await loadArticles();
    final index = articles.indexWhere((a) => a.id == id);
    if (index == -1) return null;

    final updated = articles[index].copyWith(
      teleprompterSettings: teleprompterSettings,
      updatedAt: DateTime.now(),
    );
    articles[index] = updated;
    await saveArticles(articles);
    return updated;
  }

  /// 删除稿件
  Future<bool> deleteArticle(String id) async {
    final articles = await loadArticles();
    final initialLength = articles.length;
    articles.removeWhere((a) => a.id == id);
    if (articles.length == initialLength) return false;
    await saveArticles(articles);
    return true;
  }

  /// 移动稿件到文件夹
  Future<Article?> moveArticleToFolder(
    String articleId,
    String? folderId,
  ) async {
    final articles = await loadArticles();
    final index = articles.indexWhere((a) => a.id == articleId);
    if (index == -1) return null;

    final updated = articles[index].copyWith(
      folderId: folderId,
      clearFolderId: folderId == null,
      updatedAt: DateTime.now(),
    );
    articles[index] = updated;
    await saveArticles(articles);
    return updated;
  }

  // ─── 文件夹存储 ─────────────────────────────────────────

  /// 获取所有文件夹
  Future<List<Folder>> loadFolders() async {
    final jsonStr = _prefs.getString(AppConstants.prefKeyFolders);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr) as List<dynamic>;
      return jsonList
          .map((e) => Folder.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 保存全部文件夹
  Future<void> saveFolders(List<Folder> folders) async {
    final jsonStr = jsonEncode(folders.map((f) => f.toJson()).toList());
    await _prefs.setString(AppConstants.prefKeyFolders, jsonStr);
  }

  /// 创建新文件夹
  Future<Folder> createFolder({required String name, String? parentId}) async {
    final now = DateTime.now();
    final folder = Folder(
      id: _generateId(),
      name: name,
      parentId: parentId,
      createdAt: now,
    );

    final folders = await loadFolders();
    folders.add(folder);
    await saveFolders(folders);
    return folder;
  }

  /// 重命名文件夹
  Future<Folder?> renameFolder(String id, String newName) async {
    final folders = await loadFolders();
    final index = folders.indexWhere((f) => f.id == id);
    if (index == -1) return null;

    final updated = folders[index].copyWith(name: newName);
    folders[index] = updated;
    await saveFolders(folders);
    return updated;
  }

  /// 删除文件夹（不删除子文件夹和稿件，仅解除关联）
  Future<bool> deleteFolder(String id) async {
    final folders = await loadFolders();
    final initialLength = folders.length;
    folders.removeWhere((f) => f.id == id);
    if (folders.length == initialLength) return false;
    await saveFolders(folders);

    // 将该文件夹下的稿件移回根目录
    final articles = await loadArticles();
    bool changed = false;
    for (int i = 0; i < articles.length; i++) {
      if (articles[i].folderId == id) {
        articles[i] = articles[i].copyWith(clearFolderId: true);
        changed = true;
      }
    }
    if (changed) await saveArticles(articles);

    return true;
  }

  // ─── 设置存储 ──────────────────────────────────────────────

  /// 加载应用设置
  Future<AppSettings> loadSettings() async {
    final jsonStr = _prefs.getString(AppConstants.prefKeySettings);
    if (jsonStr == null || jsonStr.isEmpty) return const AppSettings();

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return const AppSettings();
    }
  }

  /// 保存应用设置
  Future<void> saveSettings(AppSettings settings) async {
    final jsonStr = jsonEncode(settings.toJson());
    await _prefs.setString(AppConstants.prefKeySettings, jsonStr);
  }

  // ─── 工具方法 ──────────────────────────────────────────────

  /// 生成简易唯一 ID
  String _generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = (now % 100000).toRadixString(36);
    return '${now.toRadixString(36)}_$random';
  }
}
