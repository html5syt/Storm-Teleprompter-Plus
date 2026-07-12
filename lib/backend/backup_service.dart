import '../models/app_backup.dart';
import 'article_service.dart';
import 'settings_service.dart';
import 'ws_protocol.dart';
import 'ws_server.dart';

/// 处理应用完整备份的后端服务。
///
/// 该服务只协调稿件、文件夹和设置服务，不直接接触文件系统。客户端负责选择
/// 备份文件，服务端负责提供和恢复当前连接后端中的真实数据。
class BackupService {
  BackupService(this._articles, this._settings);

  final ArticleService _articles;
  final SettingsService _settings;

  /// 注册备份导出和恢复请求。
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
    final backup = AppBackup(
      createdAt: DateTime.now(),
      articles: await _articles.loadArticles(),
      folders: await _articles.loadFolders(),
      settings: await _settings.loadSettings(),
    );
    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.appBackupExportResponse,
        id: request.message.id,
        data: backup.toJson(),
      ),
    );
  }

  Future<void> _restore(WsServer server, WsRequest request) async {
    try {
      // 先完整解析，确认所有字段有效后再替换当前数据。
      final backup = AppBackup.fromJson(request.message.data);

      await _articles.replaceFolders(backup.folders);
      await _articles.replaceArticles(backup.articles);
      await _settings.saveSettings(backup.settings);
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
