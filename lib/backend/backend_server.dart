import 'dart:async';
import 'package:flutter/foundation.dart';
import 'ws_protocol.dart';
import 'ws_server.dart';
import 'article_service.dart';
import 'settings_service.dart';
import 'teleprompter_session.dart';
import 'asr_session_service.dart';
import 'backup_service.dart';

class BackendServer {
  BackendServer() {
    asrSessionService = AsrSessionService(
      settingsService,
      teleprompterSession.updateCurrentIndexFromAsr,
    );
    teleprompterSession.bindAsrSession(asrSessionService);
  }

  final WsServer wsServer = WsServer();
  final ArticleService articleService = ArticleService();
  final SettingsService settingsService = SettingsService();
  final TeleprompterSession teleprompterSession = TeleprompterSession();
  late final AsrSessionService asrSessionService;
  late final BackupService backupService = BackupService(
    articleService,
    settingsService,
  );

  bool _isRunning = false;
  int _port = 0;
  StreamSubscription? _pingSubscription;
  StreamSubscription? _clientCountSubscription;
  bool _hasMultipleClients = false;
  bool _handlersRegistered = false;

  bool get isRunning => _isRunning;

  int get port => _port;

  int get clientCount => wsServer.clientCount;

  bool get hasMultipleClients => _hasMultipleClients;

  Future<int> start({int port = 0}) async {
    if (_isRunning) {
      debugPrint('[BackendServer] 后端已在运行，端口: $_port');
      return _port;
    }

    try {
      debugPrint('[BackendServer] 正在初始化稿件服务');
      await articleService.init();
      debugPrint('[BackendServer] 稿件服务初始化完成');
      debugPrint('[BackendServer] 正在初始化设置服务');
      await settingsService.init();
      debugPrint('[BackendServer] 设置服务初始化完成');

      debugPrint('[BackendServer] 正在启动 WebSocket 服务器');
      _port = await wsServer.start(port: port);

      if (!_handlersRegistered) {
        articleService.registerHandlers(wsServer);
        settingsService.registerHandlers(wsServer);
        teleprompterSession.registerHandlers(wsServer);
        asrSessionService.registerHandlers(wsServer);
        backupService.registerHandlers(wsServer);
        _handlersRegistered = true;
      }

      _registerPingHandler();

      _monitorClientCount();

      _isRunning = true;
      debugPrint('[BackendServer] 后端服务已启动，端口: $_port');
      return _port;
    } catch (e) {
      debugPrint('[BackendServer] 启动失败: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    _pingSubscription?.cancel();
    _clientCountSubscription?.cancel();
    teleprompterSession.reset();
    await asrSessionService.shutdown();
    await wsServer.stop();

    _isRunning = false;
    _port = 0;
    _hasMultipleClients = false;
    debugPrint('[BackendServer] 后端服务已停止');
  }

  Future<void> shutdownApplication() async {
    await stop();
    await asrSessionService.release();
  }

  void _registerPingHandler() {
    _pingSubscription?.cancel();
    _pingSubscription = wsServer.requests.listen((request) {
      if (request.message.type == WsMessageType.connectionPing) {
        wsServer.respond(
          request.clientId,
          WsMessage(
            type: WsMessageType.connectionPong,
            id: request.message.id,
            data: {
              'serverTime': DateTime.now().toIso8601String(),
              'clients': wsServer.clientCount,
            },
          ),
        );
      }
    });
  }

  void _monitorClientCount() {
    _hasMultipleClients = wsServer.clientCount >= 2;

    _clientCountSubscription = Stream.periodic(const Duration(seconds: 1))
        .listen((_) {
          final newCount = wsServer.clientCount;
          final isMultiple = newCount >= 2;

          if (isMultiple != _hasMultipleClients) {
            _hasMultipleClients = isMultiple;
            if (_hasMultipleClients) {
              debugPrint(
                '[BackendServer] ⚠️ 检测到多个客户端连接 (${wsServer.clientCount} 个)，'
                '关闭应用时需要进行警告',
              );
            }
          }
        });
  }

  Map<String, dynamic> getConnectionInfo() {
    return {
      'isRunning': _isRunning,
      'port': _port,
      'clientCount': wsServer.clientCount,
      'clientIds': wsServer.clientIds,
    };
  }

  void dispose() {
    stop();
  }
}
