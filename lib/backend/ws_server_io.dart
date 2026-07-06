import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'ws_protocol.dart';

/// WebSocket 服务端
///
/// 使用 dart:io 的 HttpServer 创建 WebSocket 服务器。
/// 管理客户端连接、消息路由和广播。
class WsServer {
  HttpServer? _server;
  final Map<String, WebSocket> _clients = {};
  final StreamController<WsRequest> _requestController =
      StreamController<WsRequest>.broadcast();

  /// 服务端口
  int _port = 0;

  /// 是否正在运行
  bool get isRunning => _server != null;

  /// 当前端口
  int get port => _port;

  /// 已连接客户端数
  int get clientCount => _clients.length;

  /// 已连接客户端 ID 列表
  List<String> get clientIds => _clients.keys.toList();

  /// 请求流（供后端服务监听）
  Stream<WsRequest> get requests => _requestController.stream;

  /// 启动 WebSocket 服务器
  ///
  /// [port] 指定端口，0 表示自动分配。
  /// 返回实际绑定的端口。
  Future<int> start({int port = 0}) async {
    if (_server != null) {
      debugPrint('[WsServer] 服务器已在运行，端口: $_port');
      return _port;
    }

    try {
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
      _port = _server!.port;

      debugPrint('[WsServer] WebSocket 服务器已启动，端口: $_port');

      _server!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final ws = await WebSocketTransformer.upgrade(request);
          _handleNewClient(ws);
        } else {
          // 非 WS 请求，返回连接信息
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'status': 'running',
                'port': _port,
                'clients': _clients.length,
              }),
            )
            ..close();
        }
      });

      return _port;
    } catch (e) {
      debugPrint('[WsServer] 启动失败: $e');
      rethrow;
    }
  }

  /// 停止服务器
  Future<void> stop() async {
    debugPrint('[WsServer] 正在停止服务器...');

    // 关闭所有客户端连接
    for (final ws in _clients.values) {
      try {
        await ws.close();
      } catch (_) {}
    }
    _clients.clear();

    // 关闭服务器
    await _server?.close(force: true);
    _server = null;
    _port = 0;

    debugPrint('[WsServer] 服务器已停止');
  }

  /// 处理新客户端连接
  void _handleNewClient(WebSocket ws) {
    final clientId = 'client_${DateTime.now().microsecondsSinceEpoch}';
    ws.pingInterval = const Duration(seconds: 10);
    _clients[clientId] = ws;

    debugPrint('[WsServer] 新客户端连接: $clientId (总数: ${_clients.length})');

    // 发送连接信息
    _sendTo(
      clientId,
      WsMessage(
        type: WsMessageType.connectionInfo,
        data: {
          'clientId': clientId,
          'port': _port,
          'serverTime': DateTime.now().toIso8601String(),
        },
      ),
    );

    // 广播设备数更新
    _broadcastDeviceCount();

    // 监听消息
    ws.listen(
      (dynamic data) {
        try {
          final message = WsMessage.fromString(data as String);
          _requestController.add(
            WsRequest(clientId: clientId, message: message),
          );
        } catch (e) {
          debugPrint('[WsServer] 消息解析失败: $e');
          _sendTo(
            clientId,
            WsMessage(type: WsMessageType.error, data: {'message': '消息格式错误'}),
          );
        }
      },
      onDone: () {
        _clients.remove(clientId);
        debugPrint('[WsServer] 客户端断开: $clientId (剩余: ${_clients.length})');
        _broadcastDeviceCount();
      },
      onError: (error) {
        debugPrint('[WsServer] 客户端错误: $clientId, $error');
        _clients.remove(clientId);
        _broadcastDeviceCount();
      },
    );
  }

  /// 向指定客户端发送消息
  void _sendTo(String clientId, WsMessage message) {
    final ws = _clients[clientId];
    if (ws != null && ws.readyState == WebSocket.open) {
      ws.add(message.encode());
    }
  }

  /// 向指定客户端发送响应
  void respond(String clientId, WsMessage message) {
    _sendTo(clientId, message);
  }

  /// 广播消息给所有客户端
  void broadcast(WsMessage message) {
    final encoded = message.encode();
    for (final ws in _clients.values) {
      if (ws.readyState == WebSocket.open) {
        ws.add(encoded);
      }
    }
  }

  /// 广播设备数量给所有客户端
  void broadcastExcept(String excludedClientId, WsMessage message) {
    final encoded = message.encode();
    for (final entry in _clients.entries) {
      if (entry.key == excludedClientId) continue;
      final ws = entry.value;
      if (ws.readyState == WebSocket.open) {
        ws.add(encoded);
      }
    }
  }

  void _broadcastDeviceCount() {
    broadcast(
      WsMessage(
        type: WsMessageType.connectionDevices,
        data: {'count': _clients.length, 'clientIds': _clients.keys.toList()},
      ),
    );
  }

  /// 处理资源清理
  void dispose() {
    stop();
    _requestController.close();
  }
}

/// 封装的客户端请求
///
/// 包含来源客户端 ID 和消息内容，便于后端服务路由和响应。
class WsRequest {
  final String clientId;
  final WsMessage message;

  const WsRequest({required this.clientId, required this.message});
}
