import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../backend/ws_protocol.dart';
import '../utils/constants.dart';

class WsClient {
  WebSocketChannel? _channel;
  String? _clientId;
  bool _isConnected = false;

  final StreamController<WsMessage> _messageController =
      StreamController<WsMessage>.broadcast();

  final Map<String, Completer<WsMessage>> _pendingRequests = {};

  VoidCallback? onConnected;
  VoidCallback? onDisconnected;

  bool get isConnected => _isConnected;

  String? get clientId => _clientId;

  Stream<WsMessage> get messages => _messageController.stream;

  Future<void> connect({
    String host = NetworkConstants.loopbackHost,
    required int port,
  }) async {
    if (_isConnected) {
      debugPrint('[WsClient] 已连接，先断开');
      await disconnect();
    } else if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (_) {}
      _channel = null;
    }

    final uri = Uri.parse('ws://$host:$port');

    try {
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        (dynamic data) {
          try {
            final message = WsMessage.fromString(data as String);

            if (message.type == WsMessageType.connectionInfo) {
              _clientId = message.data['clientId'] as String?;
              debugPrint('[WsClient] 客户端 ID: $_clientId');
            }

            if (message.id != null &&
                _pendingRequests.containsKey(message.id)) {
              _pendingRequests.remove(message.id)!.complete(message);
            }

            _messageController.add(message);
          } catch (e) {
            debugPrint('[WsClient] 消息解析失败: $e');
          }
        },
        onDone: () {
          _isConnected = false;
          debugPrint('[WsClient] 连接已断开');
          onDisconnected?.call();
          _rejectPendingRequests('连接已断开');
        },
        onError: (error) {
          _isConnected = false;
          debugPrint('[WsClient] 连接错误: $error');
          onDisconnected?.call();
          _rejectPendingRequests('连接错误: $error');
        },
      );

      await _channel!.ready;

      _isConnected = true;
      debugPrint('[WsClient] 已连接到 $uri');

      onConnected?.call();
    } catch (e) {
      _isConnected = false;
      debugPrint('[WsClient] 连接失败: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }
    _isConnected = false;
    _clientId = null;
    _rejectPendingRequests('主动断开');
    onDisconnected?.call();
    debugPrint('[WsClient] 已断开连接');
  }

  void send(WsMessage message) {
    if (!_isConnected || _channel == null) {
      debugPrint('[WsClient] 未连接，无法发送消息');
      return;
    }
    _channel!.sink.add(message.encode());
  }

  Future<WsMessage> request(
    WsMessageType type, {
    Map<String, dynamic> data = const {},
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_isConnected) {
      throw WsClientException('未连接到服务器');
    }

    final id = RequestIdGenerator.next();
    final completer = Completer<WsMessage>();
    _pendingRequests[id] = completer;

    send(WsMessage(type: type, data: data, id: id));

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pendingRequests.remove(id);
      throw WsClientException('请求超时: ${type.value}');
    }
  }

  void _rejectPendingRequests(String reason) {
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(WsClientException(reason));
      }
    }
    _pendingRequests.clear();
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}

class WsClientException implements Exception {
  final String message;
  const WsClientException(this.message);

  @override
  String toString() => 'WsClientException: $message';
}
