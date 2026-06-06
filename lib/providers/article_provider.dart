import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/storage_service.dart';

/// 稿件管理状态
///
/// 管理稿件列表的增删改查操作。
class ArticleProvider with ChangeNotifier {
  List<Article> _articles = [];
  bool _isLoading = false;
  String? _error;
  StorageService? _storage;

  List<Article> get articles => _articles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 初始化并加载稿件
  Future<void> init() async {
    _storage = await StorageService.getInstance();
    await loadArticles();
  }

  /// 加载全部稿件
  Future<void> loadArticles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _articles = await _storage!.loadArticles();
    } catch (e) {
      _error = '加载稿件失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 创建新稿件
  Future<Article?> createArticle({
    required String title,
    required String content,
  }) async {
    try {
      final article = await _storage!.createArticle(
        title: title,
        content: content,
      );
      _articles.insert(0, article);
      notifyListeners();
      return article;
    } catch (e) {
      _error = '创建稿件失败: $e';
      notifyListeners();
      return null;
    }
  }

  /// 更新稿件
  Future<Article?> updateArticle(
    String id, {
    String? title,
    String? content,
  }) async {
    try {
      final updated = await _storage!.updateArticle(
        id,
        title: title,
        content: content,
      );
      if (updated != null) {
        final index = _articles.indexWhere((a) => a.id == id);
        if (index != -1) {
          _articles[index] = updated;
          // 重新排序
          _articles.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          notifyListeners();
        }
      }
      return updated;
    } catch (e) {
      _error = '更新稿件失败: $e';
      notifyListeners();
      return null;
    }
  }

  /// 删除稿件
  Future<bool> deleteArticle(String id) async {
    try {
      final success = await _storage!.deleteArticle(id);
      if (success) {
        _articles.removeWhere((a) => a.id == id);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = '删除稿件失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 搜索稿件
  List<Article> searchArticles(String query) {
    if (query.trim().isEmpty) return _articles;
    final lowerQuery = query.toLowerCase();
    return _articles.where((a) {
      return a.title.toLowerCase().contains(lowerQuery) ||
          a.content.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
