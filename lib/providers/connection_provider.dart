import 'dart:async';
import 'package:flutter/foundation.dart';
import '../backend/backend_server.dart';
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
  List<String> _deviceIds = [];
  String? _lastError;
  StreamSubscription? _messageSubscription;
  BackendServer? _localBackend;

  ConnectionProvider() {
    client.onDisconnected = _handleClientDisconnected;
  }

  ConnectionMode get mode => _mode;
  bool get isConnected => client.isConnected;
  bool get isLocal => _mode == ConnectionMode.local;
  bool get isRemote => _mode == ConnectionMode.remote;
  int get deviceCount => _deviceCount;
  List<String> get deviceIds => List.unmodifiable(_deviceIds);
  List<String> get remoteDeviceIds {
    final currentId = clientId;
    if (currentId == null || currentId.isEmpty) return deviceIds;
    return _deviceIds.where((id) => id != currentId).toList(growable: false);
  }

  String? get lastError => _lastError;
  String? get clientId => client.clientId;

  void bindLocalBackend(BackendServer backend) {
    _localBackend = backend;
  }

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

  String get connectionDetailText {
    final lines = <String>[
      connectionInfoText,
      '状态: ${isConnected ? "已连接" : "未连接"}',
    ];
    if (_remoteHost != null && _remotePort != null) {
      lines.add('地址: ws://$_remoteHost:$_remotePort');
    }
    if (clientId != null && clientId!.isNotEmpty) {
      lines.add('客户端 ID: $clientId');
    }
    if (_mode == ConnectionMode.local) {
      lines.add('角色: 本地后端拥有者 / 主控客户端');
      lines.add('远程客户端数: ${remoteDeviceIds.length}');
      if (remoteDeviceIds.isNotEmpty) {
        lines.add('传入连接 ID: ${remoteDeviceIds.join(", ")}');
      }
    } else if (_mode == ConnectionMode.remote) {
      lines.add('角色: 远程子客户端');
    }
    if (_lastError != null && _lastError!.isNotEmpty) {
      lines.add('最近错误: $_lastError');
    }
    return lines.join('\n');
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

  Future<void> connectToBundledLocal() async {
    final backend = _localBackend;
    if (backend == null) {
      _mode = ConnectionMode.disconnected;
      _lastError = '未绑定本地后端实例';
      notifyListeners();
      return;
    }

    try {
      if (!backend.isRunning) {
        await backend.start();
      }
      await connectToLocal(backend.port);
    } catch (e) {
      _mode = ConnectionMode.disconnected;
      _lastError = '启动并连接本地后端失败: $e';
      notifyListeners();
    }
  }

  /// 连接到远程后端
  Future<void> connectToRemote(String host, int port) async {
    final hadLocalBackend = _localBackend?.isRunning == true;

    try {
      await client.connect(host: host, port: port);
      if (_localBackend?.isRunning == true) {
        await _localBackend!.stop();
      }
      _remoteHost = host;
      _remotePort = port;
      _mode = ConnectionMode.remote;
      _lastError = null;
      _setupMessageListener();
      notifyListeners();
      debugPrint('[ConnectionProvider] 已连接到远程后端: $host:$port');
    } catch (e) {
      _lastError = '连接远程后端失败: $e';
      _mode = ConnectionMode.disconnected;
      if (hadLocalBackend) {
        await connectToBundledLocal();
        _lastError = '连接远程后端失败，已恢复本地后端: $e';
      }
      notifyListeners();
      rethrow;
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
    _deviceIds = [];
    notifyListeners();
  }

  Future<void> disconnectRemoteAndReconnectLocal() async {
    await disconnect();
    await connectToBundledLocal();
  }

  Future<void> stopLocalAndDisconnect() async {
    await disconnect();
    await _localBackend?.stop();
  }

  /// 设置消息监听
  void _setupMessageListener() {
    _messageSubscription?.cancel();
    _messageSubscription = client.messages.listen((message) {
      // 处理设备数更新
      if (message.type == WsMessageType.connectionDevices) {
        _deviceCount = message.data['count'] as int? ?? 0;
        _deviceIds = (message.data['clientIds'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();
        notifyListeners();
      }
    });
  }

  void _handleClientDisconnected() {
    if (_mode == ConnectionMode.disconnected) return;
    _messageSubscription?.cancel();
    _mode = ConnectionMode.disconnected;
    _deviceCount = 0;
    _deviceIds = [];
    _lastError ??= '后端连接已断开';
    notifyListeners();
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
