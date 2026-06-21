import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../backend/ws_protocol.dart';

/// WebSocket 客户端
///
/// 前端通过此客户端与后端（本地或远程）通信。
/// 支持请求-响应模式和广播消息监听。
class WsClient {
  WebSocketChannel? _channel;
  String? _clientId;
  bool _isConnected = false;

  /// 响应流控制器
  final StreamController<WsMessage> _messageController =
      StreamController<WsMessage>.broadcast();

  /// 请求-响应配对的 Completer 缓存
  final Map<String, Completer<WsMessage>> _pendingRequests = {};

  /// 连接状态变更回调
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;

  /// 是否已连接
  bool get isConnected => _isConnected;

  /// 客户端 ID（由服务器分配）
  String? get clientId => _clientId;

  /// 消息流（所有收到的消息，包括响应和广播）
  Stream<WsMessage> get messages => _messageController.stream;

  /// 连接到 WebSocket 服务器
  ///
  /// [host] 服务器地址，默认 localhost
  /// [port] 服务器端口
  Future<void> connect({String host = 'localhost', required int port}) async {
    if (_isConnected) {
      debugPrint('[WsClient] 已连接，先断开');
      await disconnect();
    }

    final uri = Uri.parse('ws://$host:$port');

    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _isConnected = true;
      debugPrint('[WsClient] 已连接到 $uri');

      // 监听消息
      _channel!.stream.listen(
        (dynamic data) {
          try {
            final message = WsMessage.fromString(data as String);

            // 处理连接信息（首次连接时服务器发送）
            if (message.type == WsMessageType.connectionInfo) {
              _clientId = message.data['clientId'] as String?;
              debugPrint('[WsClient] 客户端 ID: $_clientId');
            }

            // 如果是请求的响应，完成对应的 Completer
            if (message.id != null &&
                _pendingRequests.containsKey(message.id)) {
              _pendingRequests.remove(message.id)!.complete(message);
            }

            // 推送到消息流
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

      onConnected?.call();
    } catch (e) {
      _isConnected = false;
      debugPrint('[WsClient] 连接失败: $e');
      rethrow;
    }
  }

  /// 断开连接
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

  /// 发送消息（不等待响应）
  void send(WsMessage message) {
    if (!_isConnected || _channel == null) {
      debugPrint('[WsClient] 未连接，无法发送消息');
      return;
    }
    _channel!.sink.add(message.encode());
  }

  /// 发送请求并等待响应
  ///
  /// 自动分配请求 ID，返回对应的响应消息。
  /// [timeout] 超时时间，默认 10 秒。
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

  /// 拒绝所有待处理的请求
  void _rejectPendingRequests(String reason) {
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(WsClientException(reason));
      }
    }
    _pendingRequests.clear();
  }

  /// 清理资源
  void dispose() {
    disconnect();
    _messageController.close();
  }
}

/// WebSocket 客户端异常
class WsClientException implements Exception {
  final String message;
  const WsClientException(this.message);

  @override
  String toString() => 'WsClientException: $message';
}
