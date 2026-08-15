import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'ws_protocol.dart';

class WsServer {
  HttpServer? _server;
  final Map<String, WebSocket> _clients = {};
  final StreamController<WsRequest> _requestController =
      StreamController<WsRequest>.broadcast();

  int _port = 0;

  bool get isRunning => _server != null;

  int get port => _port;

  int get clientCount => _clients.length;

  List<String> get clientIds => _clients.keys.toList();

  Stream<WsRequest> get requests => _requestController.stream;

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

  Future<void> stop() async {
    debugPrint('[WsServer] 正在停止服务器...');

    final clients = _clients.values.toList(growable: false);
    _clients.clear();
    for (final ws in clients) {
      try {
        await ws.close();
      } catch (_) {}
    }

    await _server?.close(force: true);
    _server = null;
    _port = 0;

    debugPrint('[WsServer] 服务器已停止');
  }

  void _handleNewClient(WebSocket ws) {
    final clientId = 'client_${DateTime.now().microsecondsSinceEpoch}';
    ws.pingInterval = const Duration(seconds: 10);
    _clients[clientId] = ws;

    debugPrint('[WsServer] 新客户端连接: $clientId (总数: ${_clients.length})');

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

    _broadcastDeviceCount();

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

  void _sendTo(String clientId, WsMessage message) {
    final ws = _clients[clientId];
    if (ws != null && ws.readyState == WebSocket.open) {
      ws.add(message.encode());
    }
  }

  void respond(String clientId, WsMessage message) {
    _sendTo(clientId, message);
  }

  void broadcast(WsMessage message) {
    final encoded = message.encode();
    for (final ws in _clients.values) {
      if (ws.readyState == WebSocket.open) {
        ws.add(encoded);
      }
    }
  }

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

  void dispose() {
    stop();
    _requestController.close();
  }
}

class WsRequest {
  final String clientId;
  final WsMessage message;

  const WsRequest({required this.clientId, required this.message});
}
