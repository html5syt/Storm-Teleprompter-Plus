import 'dart:async';
import 'package:flutter/foundation.dart';
import 'ws_protocol.dart';
import 'ws_server.dart';
import 'article_service.dart';
import 'settings_service.dart';
import 'teleprompter_session.dart';

/// 后端主控
///
/// 管理所有后端服务的生命周期，包括：
/// - WebSocket 服务器
/// - 稿件管理服务
/// - 设置存储服务
/// - 提词器会话服务
///
/// 前端默认连接到本机后端，如未启动则在此启动一个。
/// 改连接到远程后端时，停止本机持有的后端实例。
class BackendServer {
  final WsServer wsServer = WsServer();
  final ArticleService articleService = ArticleService();
  final SettingsService settingsService = SettingsService();
  final TeleprompterSession teleprompterSession = TeleprompterSession();

  bool _isRunning = false;
  int _port = 0;
  StreamSubscription? _pingSubscription;
  StreamSubscription? _clientCountSubscription;
  bool _hasMultipleClients = false;

  /// 是否正在运行
  bool get isRunning => _isRunning;

  /// 服务端口
  int get port => _port;

  /// 已连接客户端数
  int get clientCount => wsServer.clientCount;

  /// 是否有多个客户端连接（≥2）
  bool get hasMultipleClients => _hasMultipleClients;

  /// 启动后端服务
  ///
  /// [port] 指定端口，0 表示自动分配。
  /// 返回实际绑定的端口。
  Future<int> start({int port = 0}) async {
    if (_isRunning) {
      debugPrint('[BackendServer] 后端已在运行，端口: $_port');
      return _port;
    }

    try {
      // 初始化所有服务
      await articleService.init();
      await settingsService.init();

      // 启动 WebSocket 服务器
      _port = await wsServer.start(port: port);

      // 注册消息处理器
      articleService.registerHandlers(wsServer);
      settingsService.registerHandlers(wsServer);
      teleprompterSession.registerHandlers(wsServer);

      // 注册 Ping/Pong 处理
      _registerPingHandler();

      // 监控客户端连接数变化
      _monitorClientCount();

      _isRunning = true;
      debugPrint('[BackendServer] 后端服务已启动，端口: $_port');
      return _port;
    } catch (e) {
      debugPrint('[BackendServer] 启动失败: $e');
      rethrow;
    }
  }

  /// 停止后端服务
  Future<void> stop() async {
    if (!_isRunning) return;

    _pingSubscription?.cancel();
    _clientCountSubscription?.cancel();
    teleprompterSession.dispose();
    await wsServer.stop();

    _isRunning = false;
    _port = 0;
    _hasMultipleClients = false;
    debugPrint('[BackendServer] 后端服务已停止');
  }

  /// 注册 Ping 处理器
  void _registerPingHandler() {
    wsServer.requests.listen((request) {
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

  /// 监控客户端连接数变化
  /// 当客户端数 ≥ 2 时，设置标志 _hasMultipleClients = true
  void _monitorClientCount() {
    // 初始检查
    _hasMultipleClients = wsServer.clientCount >= 2;

    // 定期检查客户端连接数（每秒一次）
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

  /// 获取连接信息
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
