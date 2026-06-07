import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../models/app_settings.dart';
import '../utils/constants.dart';

/// 本地存储服务
///
/// 使用 SharedPreferences 实现稿件和设置的本地持久化。
/// 无需后端服务，单次运行即可使用。
class StorageService {
  static StorageService? _instance;
  late SharedPreferences _prefs;

  StorageService._();

  /// 获取单例实例
  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      _instance!._prefs = await SharedPreferences.getInstance();
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
