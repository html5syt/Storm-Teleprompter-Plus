import '../models/app_settings.dart';
import '../models/article.dart';
import '../models/folder.dart';
import 'article_service.dart';
import 'settings_service.dart';
import 'ws_protocol.dart';
import 'ws_server.dart';

class BackupService {
  BackupService(this._articles, this._settings);

  final ArticleService _articles;
  final SettingsService _settings;

  void registerHandlers(WsServer server) {
    server.requests.listen((request) async {
      switch (request.message.type) {
        case WsMessageType.appBackupExport:
          await _export(server, request);
        case WsMessageType.appBackupRestore:
          await _restore(server, request);
        default:
          break;
      }
    });
  }

  Future<void> _export(WsServer server, WsRequest request) async {
    final articles = await _articles.loadArticles();
    final folders = await _articles.loadFolders();
    final settings = await _settings.loadSettings();
    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.appBackupExportResponse,
        id: request.message.id,
        data: {
          'format': 'storm-teleprompter-backup',
          'version': 1,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'articles': articles.map((item) => item.toJson()).toList(),
          'folders': folders.map((item) => item.toJson()).toList(),
          'settings': settings.toJson(),
        },
      ),
    );
  }

  Future<void> _restore(WsServer server, WsRequest request) async {
    try {
      final data = request.message.data;
      if (data['format'] != 'storm-teleprompter-backup' ||
          data['version'] != 1) {
        throw const FormatException('不是受支持的飓风提词器备份文件');
      }
      final articles = (data['articles'] as List<dynamic>)
          .map((item) => Article.fromJson(item as Map<String, dynamic>))
          .toList();
      final folders = (data['folders'] as List<dynamic>)
          .map((item) => Folder.fromJson(item as Map<String, dynamic>))
          .toList();
      final settings = AppSettings.fromJson(
        data['settings'] as Map<String, dynamic>,
      );

      await _articles.replaceFolders(folders);
      await _articles.replaceArticles(articles);
      await _settings.saveSettings(settings);
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.appBackupRestoreResponse,
          id: request.message.id,
          data: {'success': true},
        ),
      );
    } catch (error) {
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.error,
          id: request.message.id,
          data: {'message': '恢复备份失败：$error'},
        ),
      );
    }
  }
}
