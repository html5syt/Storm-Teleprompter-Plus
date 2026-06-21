import 'dart:async';
import 'package:flutter/foundation.dart';
import '../backend/ws_protocol.dart';
import '../models/folder.dart';
import 'connection_provider.dart';

/// 文件夹管理 Provider（前端状态管理）
class FolderProvider with ChangeNotifier {
  List<Folder> _folders = [];
  String? _currentFolderId;
  bool _isLoading = false;

  ConnectionProvider? _connection;

  List<Folder> get folders => _folders;
  String? get currentFolderId => _currentFolderId;
  bool get isLoading => _isLoading;

  /// 绑定连接
  void bindConnection(ConnectionProvider connection) {
    _connection = connection;
  }

  List<Folder> getRootFolders() =>
      _folders.where((f) => f.parentId == null).toList();

  List<Folder> getSubFolders(String parentId) =>
      _folders.where((f) => f.parentId == parentId).toList();

  Folder? getFolderById(String id) =>
      _folders.where((f) => f.id == id).firstOrNull;

  /// 构建从根到当前文件夹的面包屑路径
  List<Folder> getBreadcrumb() {
    return getBreadcrumbFrom(_currentFolderId);
  }

  /// 构建从根到指定文件夹的面包屑路径（不依赖内部状态）
  List<Folder> getBreadcrumbFrom(String? folderId) {
    if (folderId == null) return [];
    final path = <Folder>[];
    String? id = folderId;
    while (id != null) {
      final folder = getFolderById(id);
      if (folder == null) break;
      path.insert(0, folder);
      id = folder.parentId;
    }
    return path;
  }

  /// 初始化并加载
  Future<void> init() async {
    await loadFolders();
  }

  /// 从后端加载文件夹
  Future<void> loadFolders() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (_connection != null && _connection!.isConnected) {
        final response = await _connection!.request(WsMessageType.folderList);
        if (response.type == WsMessageType.folderListResponse) {
          final list = response.data['folders'] as List<dynamic>? ?? [];
          _folders = list
              .map((e) => Folder.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[FolderProvider] 加载失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 创建文件夹
  Future<void> createFolder(String name, {String? parentId}) async {
    try {
      if (_connection != null && _connection!.isConnected) {
        final response = await _connection!.request(
          WsMessageType.folderCreate,
          data: {'name': name, if (parentId != null) 'parentId': parentId},
        );
        if (response.type == WsMessageType.folderCreateResponse) {
          final folder = Folder.fromJson(
            response.data['folder'] as Map<String, dynamic>,
          );
          _folders.add(folder);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[FolderProvider] 创建失败: $e');
    }
  }

  /// 重命名文件夹
  Future<void> renameFolder(String folderId, String newName) async {
    try {
      if (_connection != null && _connection!.isConnected) {
        final response = await _connection!.request(
          WsMessageType.folderRename,
          data: {'id': folderId, 'newName': newName},
        );
        if (response.type == WsMessageType.folderRenameResponse &&
            response.data['success'] == true) {
          final folderJson = response.data['folder'] as Map<String, dynamic>?;
          if (folderJson != null) {
            final idx = _folders.indexWhere((f) => f.id == folderId);
            if (idx >= 0) {
              _folders[idx] = Folder.fromJson(folderJson);
              notifyListeners();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[FolderProvider] 重命名失败: $e');
    }
  }

  /// 删除文件夹
  Future<void> deleteFolder(String folderId) async {
    try {
      if (_connection != null && _connection!.isConnected) {
        final response = await _connection!.request(
          WsMessageType.folderDelete,
          data: {'id': folderId},
        );
        if (response.type == WsMessageType.folderDeleteResponse &&
            response.data['success'] == true) {
          _folders.removeWhere((f) => f.id == folderId);
          // 清除子文件夹的引用
          for (int i = _folders.length - 1; i >= 0; i--) {
            if (_folders[i].parentId == folderId) {
              _folders[i] = _folders[i].copyWith(parentId: null);
            }
          }
          if (_currentFolderId == folderId) _currentFolderId = null;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[FolderProvider] 删除失败: $e');
    }
  }

  /// 设置当前文件夹
  void setCurrentFolder(String? folderId) {
    _currentFolderId = folderId;
    notifyListeners();
  }

  /// 移动文件夹到新的父文件夹
  Future<void> moveFolder(String folderId, String? newParentId) async {
    try {
      if (_connection != null && _connection!.isConnected) {
        // 通过重命名接口无法移动，直接更新 parentId
        // 暂用本地更新，后端需要新增 moveFolder 消息
        final idx = _folders.indexWhere((f) => f.id == folderId);
        if (idx >= 0) {
          _folders[idx] = _folders[idx].copyWith(parentId: newParentId);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[FolderProvider] 移动失败: $e');
    }
  }

  void clear() {
    _folders.clear();
    _currentFolderId = null;
    notifyListeners();
  }
}
