import 'dart:async';
import 'package:flutter/foundation.dart';
import '../backend/ws_protocol.dart';
import '../frontend/ws_client.dart';

/// 连接模式
enum ConnectionMode {
  /// 未连接
  disconnected,

  /// 连接到本地后端
  local,

  /// 连接到远程后端
  remote,
}

/// 连接状态管理 Provider
///
/// 管理前端与后端的 WebSocket 连接状态。
/// 前端默认连接到程序自身创建的后端。
/// 改连接到远程后端时，停止本机持有的后端实例。
class ConnectionProvider with ChangeNotifier {
  final WsClient client = WsClient();

  ConnectionMode _mode = ConnectionMode.disconnected;
  String? _remoteHost;
  int? _remotePort;
  int _deviceCount = 0;
  String? _lastError;
  StreamSubscription? _messageSubscription;

  ConnectionMode get mode => _mode;
  bool get isConnected => client.isConnected;
  bool get isLocal => _mode == ConnectionMode.local;
  bool get isRemote => _mode == ConnectionMode.remote;
  int get deviceCount => _deviceCount;
  String? get lastError => _lastError;
  String? get clientId => client.clientId;

  /// 获取连接信息文本
  String get connectionInfoText {
    switch (_mode) {
      case ConnectionMode.disconnected:
        return '未连接';
      case ConnectionMode.local:
        return '本地后端 (端口: ${_remotePort ?? "?"})';
      case ConnectionMode.remote:
        return '远程后端 ($_remoteHost:$_remotePort)';
    }
  }

  /// 初始化：连接到本地后端
  Future<void> connectToLocal(int port) async {
    _remoteHost = 'localhost';
    _remotePort = port;

    try {
      await client.connect(host: 'localhost', port: port);
      _mode = ConnectionMode.local;
      _lastError = null;
      _setupMessageListener();
      notifyListeners();
      debugPrint('[ConnectionProvider] 已连接到本地后端，端口: $port');
    } catch (e) {
      _lastError = '连接本地后端失败: $e';
      notifyListeners();
    }
  }

  /// 连接到远程后端
  Future<void> connectToRemote(String host, int port) async {
    _remoteHost = host;
    _remotePort = port;

    try {
      await client.connect(host: host, port: port);
      _mode = ConnectionMode.remote;
      _lastError = null;
      _setupMessageListener();
      notifyListeners();
      debugPrint('[ConnectionProvider] 已连接到远程后端: $host:$port');
    } catch (e) {
      _lastError = '连接远程后端失败: $e';
      notifyListeners();
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    _messageSubscription?.cancel();
    await client.disconnect();
    _mode = ConnectionMode.disconnected;
    _remoteHost = null;
    _remotePort = null;
    _deviceCount = 0;
    notifyListeners();
  }

  /// 设置消息监听
  void _setupMessageListener() {
    _messageSubscription?.cancel();
    _messageSubscription = client.messages.listen((message) {
      // 处理设备数更新
      if (message.type == WsMessageType.connectionDevices) {
        _deviceCount = message.data['count'] as int? ?? 0;
        notifyListeners();
      }
    });
  }

  /// 发送请求并等待响应
  Future<WsMessage> request(
    WsMessageType type, {
    Map<String, dynamic> data = const {},
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return client.request(type, data: data, timeout: timeout);
  }

  /// 发送消息（不等待响应）
  void send(WsMessage message) {
    client.send(message);
  }

  /// 监听特定类型的消息
  Stream<WsMessage> listenTo(WsMessageType type) {
    return client.messages.where((m) => m.type == type);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    client.dispose();
    super.dispose();
  }
}
