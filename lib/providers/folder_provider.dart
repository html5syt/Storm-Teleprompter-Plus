import 'dart:async';
import 'package:flutter/foundation.dart';
import '../backend/ws_protocol.dart';
import '../models/folder.dart';
import 'connection_provider.dart';

class FolderProvider with ChangeNotifier {
  List<Folder> _folders = [];
  String? _currentFolderId;
  bool _isLoading = false;

  ConnectionProvider? _connection;
  VoidCallback? _connectionListener;

  List<Folder> get folders => _folders;
  String? get currentFolderId => _currentFolderId;
  bool get isLoading => _isLoading;

  void bindConnection(ConnectionProvider connection) {
    if (_connection != null && _connectionListener != null) {
      _connection!.removeListener(_connectionListener!);
    }
    _connection = connection;
    _connectionListener = () {
      if (!connection.isConnected) {
        _folders = [];
        _currentFolderId = null;
        _isLoading = false;
        notifyListeners();
      }
    };
    connection.addListener(_connectionListener!);
  }

  List<Folder> getRootFolders() =>
      _folders.where((f) => f.parentId == null).toList();

  List<Folder> getSubFolders(String parentId) =>
      _folders.where((f) => f.parentId == parentId).toList();

  Folder? getFolderById(String id) =>
      _folders.where((f) => f.id == id).firstOrNull;

  List<Folder> getBreadcrumb() {
    return getBreadcrumbFrom(_currentFolderId);
  }

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

  Future<void> init() async {
    await loadFolders();
  }

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

  Future<Folder?> createFolder(String name, {String? parentId}) async {
    try {
      if (_connection != null && _connection!.isConnected) {
        final response = await _connection!.request(
          WsMessageType.folderCreate,
          data: {'name': name, 'parentId': ?parentId},
        );
        if (response.type == WsMessageType.folderCreateResponse) {
          final folder = Folder.fromJson(
            response.data['folder'] as Map<String, dynamic>,
          );
          _folders.add(folder);
          notifyListeners();
          return folder;
        }
      }
    } catch (e) {
      debugPrint('[FolderProvider] 创建失败: $e');
    }
    return null;
  }

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
          for (int i = _folders.length - 1; i >= 0; i--) {
            if (_folders[i].parentId == folderId) {
              _folders[i] = _folders[i].copyWith(clearParentId: true);
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

  void setCurrentFolder(String? folderId) {
    _currentFolderId = folderId;
    notifyListeners();
  }

  Future<void> moveFolder(String folderId, String? newParentId) async {
    try {
      if (_connection != null && _connection!.isConnected) {
        final response = await _connection!.request(
          WsMessageType.folderMove,
          data: {'folderId': folderId, 'parentId': newParentId},
        );
        if (response.type == WsMessageType.folderMoveResponse &&
            response.data['success'] == true) {
          final moved = Folder.fromJson(
            response.data['folder'] as Map<String, dynamic>,
          );
          final idx = _folders.indexWhere((folder) => folder.id == folderId);
          if (idx >= 0) _folders[idx] = moved;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[FolderProvider] 移动失败: $e');
    }
  }

  Future<bool> copyFolder(String folderId, String? newParentId) async {
    try {
      if (_connection == null || !_connection!.isConnected) return false;
      final response = await _connection!.request(
        WsMessageType.folderCopy,
        data: {'folderId': folderId, 'parentId': newParentId},
      );
      if (response.type != WsMessageType.folderCopyResponse ||
          response.data['success'] != true) {
        return false;
      }
      final folders = response.data['folders'] as List<dynamic>? ?? const [];
      _folders.addAll(
        folders.map(
          (folder) => Folder.fromJson(folder as Map<String, dynamic>),
        ),
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[FolderProvider] 复制失败: $e');
      return false;
    }
  }

  void clear() {
    _folders.clear();
    _currentFolderId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_connection != null && _connectionListener != null) {
      _connection!.removeListener(_connectionListener!);
    }
    super.dispose();
  }
}
