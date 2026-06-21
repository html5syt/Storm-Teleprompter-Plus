import 'package:flutter/material.dart';
import '../backend/ws_protocol.dart';
import '../models/article.dart';
import 'connection_provider.dart';

/// 稿件管理状态（前端）
///
/// 通过 WebSocket 与后端通信，管理稿件列表的增删改查操作。
class ArticleProvider with ChangeNotifier {
  List<Article> _articles = [];
  bool _isLoading = false;
  String? _error;

  ConnectionProvider? _connection;

  List<Article> get articles => _articles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 绑定连接
  void bindConnection(ConnectionProvider connection) {
    _connection = connection;
  }

  /// 初始化并加载稿件
  Future<void> init() async {
    await loadArticles();
  }

  /// 从后端加载全部稿件
  Future<void> loadArticles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_connection != null && _connection!.isConnected) {
        final response = await _connection!.request(WsMessageType.articleList);
        if (response.type == WsMessageType.articleListResponse) {
          final list = response.data['articles'] as List<dynamic>? ?? [];
          _articles = list
              .map((e) => Article.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
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
    String? folderId,
  }) async {
    try {
      if (_connection != null && _connection!.isConnected) {
        final response = await _connection!.request(
          WsMessageType.articleCreate,
          data: {
            'title': title,
            'content': content,
            if (folderId != null) 'folderId': folderId,
          },
        );
        if (response.type == WsMessageType.articleCreateResponse) {
          final article = Article.fromJson(
            response.data['article'] as Map<String, dynamic>,
          );
          _articles.insert(0, article);
          notifyListeners();
          return article;
        }
      }
      return null;
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
      if (_connection != null && _connection!.isConnected) {
        final response = await _connection!.request(
          WsMessageType.articleUpdate,
          data: {
            'id': id,
            if (title != null) 'title': title,
            if (content != null) 'content': content,
          },
        );
        if (response.type == WsMessageType.articleUpdateResponse &&
            response.data['success'] == true) {
          final article = Article.fromJson(
            response.data['article'] as Map<String, dynamic>,
          );
          final index = _articles.indexWhere((a) => a.id == id);
          if (index != -1) {
            _articles[index] = article;
            _articles.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            notifyListeners();
          }
          return article;
        }
      }
      return null;
    } catch (e) {
      _error = '更新稿件失败: $e';
      notifyListeners();
      return null;
    }
  }

  /// 更新稿件的提词器设置
  Future<Article?> updateArticleTeleprompterSettings(
    String id,
    Map<String, dynamic> teleprompterSettings,
  ) async {
    try {
      if (_connection != null && _connection!.isConnected) {
        final response = await _connection!.request(
          WsMessageType.articleUpdate,
          data: {'id': id, 'teleprompterSettings': teleprompterSettings},
        );
        if (response.type == WsMessageType.articleUpdateResponse &&
            response.data['success'] == true) {
          final article = Article.fromJson(
            response.data['article'] as Map<String, dynamic>,
          );
          final index = _articles.indexWhere((a) => a.id == id);
          if (index != -1) {
            _articles[index] = article;
            notifyListeners();
          }
          return article;
        }
      }
      return null;
    } catch (e) {
      _error = '更新稿件提词器设置失败: $e';
      notifyListeners();
      return null;
    }
  }

  /// 删除稿件
  Future<bool> deleteArticle(String id) async {
    try {
      if (_connection != null && _connection!.isConnected) {
        final response = await _connection!.request(
          WsMessageType.articleDelete,
          data: {'id': id},
        );
        if (response.type == WsMessageType.articleDeleteResponse &&
            response.data['success'] == true) {
          _articles.removeWhere((a) => a.id == id);
          notifyListeners();
          return true;
        }
      }
      return false;
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

  /// 获取指定文件夹中的稿件
  List<Article> getArticlesInFolder(String? folderId) {
    return _articles.where((a) => a.folderId == folderId).toList();
  }

  /// 将稿件移动到文件夹
  Future<Article?> getArticleById(String id) async {
    final cached = _articles.where((a) => a.id == id).firstOrNull;
    if (cached != null) return cached;

    try {
      if (_connection != null && _connection!.isConnected) {
        final response = await _connection!.request(
          WsMessageType.articleGet,
          data: {'id': id},
        );
        if (response.type == WsMessageType.articleGetResponse) {
          final article = Article.fromJson(
            response.data['article'] as Map<String, dynamic>,
          );
          _articles.removeWhere((a) => a.id == article.id);
          _articles.insert(0, article);
          notifyListeners();
          return article;
        }
      }
    } catch (e) {
      _error = '获取稿件失败: $e';
      notifyListeners();
    }
    return null;
  }

  Future<bool> moveArticleToFolder(String articleId, String? folderId) async {
    try {
      if (_connection != null && _connection!.isConnected) {
        final response = await _connection!.request(
          WsMessageType.folderMoveArticle,
          data: {'articleId': articleId, 'folderId': folderId},
        );

        if (response.type == WsMessageType.folderMoveArticleResponse) {
          final updatedData = response.data['article'] as Map<String, dynamic>;
          final updatedArticle = Article.fromJson(updatedData);

          final index = _articles.indexWhere((a) => a.id == articleId);
          if (index >= 0) {
            _articles[index] = updatedArticle;
            notifyListeners();
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[ArticleProvider] 移动稿件失败: $e');
      return false;
    }
  }

  /// 删除文件夹及其包含的所有稿件
  Future<void> deleteFolderWithArticles(String folderId) async {
    try {
      // 获取该文件夹中的所有稿件
      final articlesInFolder = getArticlesInFolder(folderId);

      // 删除这些稿件
      for (final article in articlesInFolder) {
        await deleteArticle(article.id);
      }

      debugPrint('[ArticleProvider] 删除文件夹及其稿件: $folderId');
    } catch (e) {
      debugPrint('[ArticleProvider] 删除失败: $e');
      rethrow;
    }
  }
}
