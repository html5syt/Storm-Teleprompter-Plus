import 'dart:convert';
import '../models/article.dart';
import '../models/folder.dart';
import '../services/app_preferences.dart';
import '../utils/constants.dart';
import 'ws_protocol.dart';
import 'ws_server.dart';

/// 稿件与文件夹管理后端服务
///
/// 处理稿件和文件夹的 CRUD 操作，通过 WebSocket 向前端提供数据。
/// 底层使用统一应用数据存储持久化。
class ArticleService {
  late AppPreferences _prefs;

  /// 初始化存储
  Future<void> init() async {
    _prefs = await AppPreferences.getInstance();
  }

  /// 注册消息处理器到 WsServer
  void registerHandlers(WsServer server) {
    // 稿件操作
    server.requests.listen((request) {
      switch (request.message.type) {
        case WsMessageType.articleList:
          _handleArticleList(server, request);
          break;
        case WsMessageType.articleGet:
          _handleArticleGet(server, request);
          break;
        case WsMessageType.articleCreate:
          _handleArticleCreate(server, request);
          break;
        case WsMessageType.articleUpdate:
          _handleArticleUpdate(server, request);
          break;
        case WsMessageType.articleDelete:
          _handleArticleDelete(server, request);
          break;
        case WsMessageType.articleExport:
          _handleArticleExport(server, request);
          break;
        case WsMessageType.articleImport:
          _handleArticleImport(server, request);
          break;
        case WsMessageType.folderList:
          _handleFolderList(server, request);
          break;
        case WsMessageType.folderCreate:
          _handleFolderCreate(server, request);
          break;
        case WsMessageType.folderRename:
          _handleFolderRename(server, request);
          break;
        case WsMessageType.folderDelete:
          _handleFolderDelete(server, request);
          break;
        case WsMessageType.folderMoveArticle:
          _handleFolderMoveArticle(server, request);
          break;
        default:
          break;
      }
    });
  }

  // ─── 稿件处理器 ─────────────────────────────────────────

  Future<void> _handleArticleList(WsServer server, WsRequest request) async {
    final articles = await loadArticles();
    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.articleListResponse,
        id: request.message.id,
        data: {'articles': articles.map((a) => a.toJson()).toList()},
      ),
    );
  }

  Future<void> _handleArticleGet(WsServer server, WsRequest request) async {
    final id = request.message.data['id'] as String?;
    if (id == null) {
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.error,
          id: request.message.id,
          data: {'message': '缺少稿件 ID'},
        ),
      );
      return;
    }

    final articles = await loadArticles();
    final article = articles.where((a) => a.id == id).firstOrNull;
    if (article == null) {
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.error,
          id: request.message.id,
          data: {'message': '稿件不存在'},
        ),
      );
      return;
    }

    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.articleGetResponse,
        id: request.message.id,
        data: {'article': article.toJson()},
      ),
    );
  }

  Future<void> _handleArticleCreate(WsServer server, WsRequest request) async {
    final data = request.message.data;
    final title = data['title'] as String? ?? '';
    final content = data['content'] as String? ?? '';
    final folderId = data['folderId'] as String?;

    final article = await createArticle(
      title: title,
      content: content,
      folderId: folderId,
    );
    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.articleCreateResponse,
        id: request.message.id,
        data: {'article': article.toJson()},
      ),
    );
    // 广播变更给其他客户端
    server.broadcast(
      WsMessage(
        type: WsMessageType.articleCreateResponse,
        data: {'article': article.toJson(), 'broadcast': true},
      ),
    );
  }

  Future<void> _handleArticleUpdate(WsServer server, WsRequest request) async {
    final data = request.message.data;
    final id = data['id'] as String?;
    if (id == null) {
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.error,
          id: request.message.id,
          data: {'message': '缺少稿件 ID'},
        ),
      );
      return;
    }

    final updated = await updateArticle(
      id,
      title: data['title'] as String?,
      content: data['content'] as String?,
      teleprompterSettings: data['teleprompterSettings'] == null
          ? null
          : Map<String, dynamic>.from(data['teleprompterSettings'] as Map),
    );

    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.articleUpdateResponse,
        id: request.message.id,
        data: {
          if (updated != null) 'article': updated.toJson(),
          'success': updated != null,
        },
      ),
    );
    // 广播变更
    if (updated != null) {
      server.broadcast(
        WsMessage(
          type: WsMessageType.articleUpdateResponse,
          data: {
            'article': updated.toJson(),
            'success': true,
            'broadcast': true,
          },
        ),
      );
    }
  }

  Future<void> _handleArticleDelete(WsServer server, WsRequest request) async {
    final id = request.message.data['id'] as String?;
    if (id == null) {
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.error,
          id: request.message.id,
          data: {'message': '缺少稿件 ID'},
        ),
      );
      return;
    }

    final success = await deleteArticle(id);
    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.articleDeleteResponse,
        id: request.message.id,
        data: {'success': success},
      ),
    );
    // 广播删除
    if (success) {
      server.broadcast(
        WsMessage(
          type: WsMessageType.articleDeleteResponse,
          data: {'id': id, 'success': true, 'broadcast': true},
        ),
      );
    }
  }

  Future<void> _handleArticleExport(WsServer server, WsRequest request) async {
    final id = request.message.data['id'] as String?;
    if (id == null) {
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.error,
          id: request.message.id,
          data: {'message': '缺少稿件 ID'},
        ),
      );
      return;
    }

    final articles = await loadArticles();
    final article = articles.where((a) => a.id == id).firstOrNull;
    if (article == null) {
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.error,
          id: request.message.id,
          data: {'message': '稿件不存在'},
        ),
      );
      return;
    }

    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.articleExportResponse,
        id: request.message.id,
        data: {'article': article.toJson()},
      ),
    );
  }

  Future<void> _handleArticleImport(WsServer server, WsRequest request) async {
    final data = request.message.data;
    final articleJson = data['article'] as Map<String, dynamic>?;
    if (articleJson == null) {
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.error,
          id: request.message.id,
          data: {'message': '缺少稿件数据'},
        ),
      );
      return;
    }

    try {
      final article = Article.fromJson(articleJson);
      final created = await createArticle(
        title: article.title,
        content: article.content,
      );
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.articleImportResponse,
          id: request.message.id,
          data: {'article': created.toJson(), 'success': true},
        ),
      );
    } catch (e) {
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.error,
          id: request.message.id,
          data: {'message': '导入失败: $e'},
        ),
      );
    }
  }

  // ─── 文件夹处理器 ───────────────────────────────────────

  Future<void> _handleFolderList(WsServer server, WsRequest request) async {
    final folders = await loadFolders();
    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.folderListResponse,
        id: request.message.id,
        data: {'folders': folders.map((f) => f.toJson()).toList()},
      ),
    );
  }

  Future<void> _handleFolderCreate(WsServer server, WsRequest request) async {
    final data = request.message.data;
    final name = data['name'] as String? ?? '';
    final parentId = data['parentId'] as String?;

    final folder = await createFolder(name: name, parentId: parentId);
    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.folderCreateResponse,
        id: request.message.id,
        data: {'folder': folder.toJson()},
      ),
    );
    // 广播
    server.broadcast(
      WsMessage(
        type: WsMessageType.folderCreateResponse,
        data: {'folder': folder.toJson(), 'broadcast': true},
      ),
    );
  }

  Future<void> _handleFolderRename(WsServer server, WsRequest request) async {
    final data = request.message.data;
    final id = data['id'] as String?;
    final newName = data['newName'] as String?;
    if (id == null || newName == null) {
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.error,
          id: request.message.id,
          data: {'message': '缺少参数'},
        ),
      );
      return;
    }

    final folder = await renameFolder(id, newName);
    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.folderRenameResponse,
        id: request.message.id,
        data: {
          if (folder != null) 'folder': folder.toJson(),
          'success': folder != null,
        },
      ),
    );
    // 广播
    if (folder != null) {
      server.broadcast(
        WsMessage(
          type: WsMessageType.folderRenameResponse,
          data: {'folder': folder.toJson(), 'success': true, 'broadcast': true},
        ),
      );
    }
  }

  Future<void> _handleFolderDelete(WsServer server, WsRequest request) async {
    final id = request.message.data['id'] as String?;
    if (id == null) {
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.error,
          id: request.message.id,
          data: {'message': '缺少文件夹 ID'},
        ),
      );
      return;
    }

    final success = await deleteFolder(id);
    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.folderDeleteResponse,
        id: request.message.id,
        data: {'success': success},
      ),
    );
    // 广播删除
    if (success) {
      server.broadcast(
        WsMessage(
          type: WsMessageType.folderDeleteResponse,
          data: {'id': id, 'success': true, 'broadcast': true},
        ),
      );
    }
  }

  Future<void> _handleFolderMoveArticle(
    WsServer server,
    WsRequest request,
  ) async {
    final data = request.message.data;
    final articleId = data['articleId'] as String?;
    final folderId = data['folderId'] as String?;
    if (articleId == null) {
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.error,
          id: request.message.id,
          data: {'message': '缺少稿件 ID'},
        ),
      );
      return;
    }

    final article = await moveArticleToFolder(articleId, folderId);
    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.folderMoveArticleResponse,
        id: request.message.id,
        data: {
          if (article != null) 'article': article.toJson(),
          'success': article != null,
        },
      ),
    );
    // 广播移动
    if (article != null) {
      server.broadcast(
        WsMessage(
          type: WsMessageType.folderMoveArticleResponse,
          data: {
            'article': article.toJson(),
            'success': true,
            'broadcast': true,
          },
        ),
      );
    }
  }

  // ─── 底层存储操作 ───────────────────────────────────────

  /// 获取所有稿件列表
  Future<List<Article>> loadArticles() async {
    final jsonStr = _prefs.getString(StorageConstants.articlesKey);
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
  Future<void> _saveArticles(List<Article> articles) async {
    final jsonStr = jsonEncode(articles.map((a) => a.toJson()).toList());
    await _prefs.setString(StorageConstants.articlesKey, jsonStr);
  }

  Future<void> replaceArticles(List<Article> articles) =>
      _saveArticles(articles);

  /// 创建新稿件
  Future<Article> createArticle({
    required String title,
    required String content,
    String? folderId,
  }) async {
    final now = DateTime.now();
    final article = Article(
      id: _generateId(),
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
      folderId: folderId,
    );

    final articles = await loadArticles();
    articles.insert(0, article);
    await _saveArticles(articles);
    return article;
  }

  /// 更新稿件
  Future<Article?> updateArticle(
    String id, {
    String? title,
    String? content,
    Map<String, dynamic>? teleprompterSettings,
  }) async {
    final articles = await loadArticles();
    final index = articles.indexWhere((a) => a.id == id);
    if (index == -1) return null;

    final updated = articles[index].copyWith(
      title: title,
      content: content,
      teleprompterSettings: teleprompterSettings,
      updatedAt: DateTime.now(),
    );
    articles[index] = updated;
    await _saveArticles(articles);
    return updated;
  }

  /// 删除稿件
  Future<bool> deleteArticle(String id) async {
    final articles = await loadArticles();
    final initialLength = articles.length;
    articles.removeWhere((a) => a.id == id);
    if (articles.length == initialLength) return false;
    await _saveArticles(articles);
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
    await _saveArticles(articles);
    return updated;
  }

  /// 获取所有文件夹
  Future<List<Folder>> loadFolders() async {
    final jsonStr = _prefs.getString(StorageConstants.foldersKey);
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
  Future<void> _saveFolders(List<Folder> folders) async {
    final jsonStr = jsonEncode(folders.map((f) => f.toJson()).toList());
    await _prefs.setString(StorageConstants.foldersKey, jsonStr);
  }

  Future<void> replaceFolders(List<Folder> folders) => _saveFolders(folders);

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
    await _saveFolders(folders);
    return folder;
  }

  /// 重命名文件夹
  Future<Folder?> renameFolder(String id, String newName) async {
    final folders = await loadFolders();
    final index = folders.indexWhere((f) => f.id == id);
    if (index == -1) return null;

    final updated = folders[index].copyWith(name: newName);
    folders[index] = updated;
    await _saveFolders(folders);
    return updated;
  }

  /// 删除文件夹
  Future<bool> deleteFolder(String id) async {
    final folders = await loadFolders();
    final initialLength = folders.length;
    folders.removeWhere((f) => f.id == id);
    if (folders.length == initialLength) return false;
    await _saveFolders(folders);

    // 将该文件夹下的稿件移回根目录
    final articles = await loadArticles();
    bool changed = false;
    for (int i = 0; i < articles.length; i++) {
      if (articles[i].folderId == id) {
        articles[i] = articles[i].copyWith(clearFolderId: true);
        changed = true;
      }
    }
    if (changed) await _saveArticles(articles);

    return true;
  }

  /// 生成简易唯一 ID
  String _generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = (now % 100000).toRadixString(36);
    return '${now.toRadixString(36)}_$random';
  }
}
