import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../backend/backend_server.dart';
import '../backend/ws_protocol.dart';
import '../frontend/ws_client.dart';
import '../services/network_info_service.dart';
import '../services/app_preferences.dart';

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
  static const _historyPrefsKey = 'remote_connection_history';
  static const _maxRemoteConnectionHistory = 5;
  final WsClient client = WsClient();

  ConnectionMode _mode = ConnectionMode.disconnected;
  String? _remoteHost;
  int? _remotePort;
  int _deviceCount = 0;
  List<String> _deviceIds = [];
  List<String> _localLanIps = [];
  List<RemoteConnectionRecord> _remoteConnectionHistory = [];
  String? _lastError;
  StreamSubscription? _messageSubscription;
  BackendServer? _localBackend;

  ConnectionProvider() {
    client.onDisconnected = _handleClientDisconnected;
    unawaited(_loadRemoteConnectionHistory());
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
  String? get remoteHost => _remoteHost;
  int? get remotePort => _remotePort;
  List<String> get localLanIps => List.unmodifiable(_localLanIps);
  List<RemoteConnectionRecord> get remoteConnectionHistory =>
      List.unmodifiable(_remoteConnectionHistory);
  List<String> get localServerUrls {
    final port = _remotePort;
    if (port == null || _localLanIps.isEmpty) return const [];
    return _localLanIps.map((ip) => 'ws://$ip:$port').toList(growable: false);
  }

  String get roleText {
    switch (_mode) {
      case ConnectionMode.disconnected:
        return '未连接';
      case ConnectionMode.local:
        return remoteDeviceIds.isEmpty ? '本机服务端 + 本机客户端' : '服务端 + 本机客户端';
      case ConnectionMode.remote:
        return '客户端（连接服务端）';
    }
  }

  void bindLocalBackend(BackendServer backend) {
    _localBackend = backend;
  }

  Future<void> refreshLocalLanIps() async {
    await _loadLocalLanIps();
    notifyListeners();
  }

  Future<void> _loadLocalLanIps() async {
    try {
      _localLanIps = await getLocalLanIPv4Addresses();
    } catch (e) {
      _localLanIps = [];
      debugPrint('[ConnectionProvider] 获取局域网 IP 失败: $e');
    }
  }

  String get connectionTypeText {
    switch (_mode) {
      case ConnectionMode.disconnected:
        return '未连接';
      case ConnectionMode.local:
        return '本地';
      case ConnectionMode.remote:
        return '远程';
    }
  }

  /// 获取连接信息文本
  String get connectionInfoText =>
      connectionTypeText == '未连接' ? '未连接服务端' : '服务端连接信息';

  String get connectionDetailText {
    final lines = <String>[
      '服务端连接信息',
      '连接类型：$connectionTypeText',
      '本机IP：${_localLanIps.isEmpty ? "未检测到" : _localLanIps.join(", ")}',
      '端口号：${_mode == ConnectionMode.local ? (_remotePort ?? "-") : "-"}',
    ];
    if (_mode == ConnectionMode.remote && _remoteHost != null) {
      lines.add('远程IP：$_remoteHost');
      lines.add('远程端口号：${_remotePort ?? "-"}');
    }
    if (_mode == ConnectionMode.local) {
      lines.add('已连接客户端：$_deviceCount');
    }
    if (_lastError != null && _lastError!.isNotEmpty) {
      lines.add('最近错误：$_lastError');
    }
    return lines.join('\n');
  }

  String get connectionDetailBodyText {
    final lines = connectionDetailText.split('\n');
    if (lines.length <= 1) return '';
    return lines.skip(1).join('\n');
  }

  bool get canRetryRemoteConnection =>
      _mode == ConnectionMode.disconnected &&
      _remoteHost != null &&
      _remotePort != null;

  Future<void> _loadRemoteConnectionHistory() async {
    try {
      final prefs = await AppPreferences.getInstance();
      final raw = prefs.getString(_historyPrefsKey);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      _remoteConnectionHistory = list
          .map(
            (item) => RemoteConnectionRecord.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where((record) => record.host.isNotEmpty && record.port > 0)
          .take(_maxRemoteConnectionHistory)
          .toList(growable: false);
      notifyListeners();
    } catch (e) {
      debugPrint('[ConnectionProvider] 加载连接历史失败: $e');
    }
  }

  Future<void> _saveRemoteConnectionHistory() async {
    final prefs = await AppPreferences.getInstance();
    await prefs.setString(
      _historyPrefsKey,
      jsonEncode(
        _remoteConnectionHistory.map((item) => item.toJson()).toList(),
      ),
    );
  }

  Future<void> _rememberRemoteConnection(String host, int port) async {
    final normalizedHost = host.trim();
    _remoteConnectionHistory = [
      RemoteConnectionRecord(
        host: normalizedHost,
        port: port,
        updatedAt: DateTime.now(),
      ),
      ..._remoteConnectionHistory.where(
        (item) => item.host != normalizedHost || item.port != port,
      ),
    ].take(_maxRemoteConnectionHistory).toList(growable: false);
    notifyListeners();
    await _saveRemoteConnectionHistory();
  }

  /// 初始化：连接到本地后端
  Future<void> connectToLocal(int port) async {
    if (client.isConnected || canRetryRemoteConnection) {
      await client.disconnect();
    }
    _remoteHost = 'localhost';
    _remotePort = port;
    _lastError = null;

    try {
      await client.connect(host: 'localhost', port: port);
      _mode = ConnectionMode.local;
      _lastError = null;
      _setupMessageListener();
      notifyListeners();
      unawaited(refreshLocalLanIps());
      debugPrint('[ConnectionProvider] 已连接到本机服务端，端口: $port');
    } catch (e) {
      _lastError = '连接本机服务端失败: $e';
      notifyListeners();
    }
  }

  Future<void> connectToBundledLocal() async {
    final backend = _localBackend;
    if (backend == null) {
      _mode = ConnectionMode.disconnected;
      _lastError = '未绑定本机服务端实例';
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
      _lastError = '启动并连接本机服务端失败: $e';
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
      unawaited(refreshLocalLanIps());
      unawaited(_rememberRemoteConnection(host, port));
      debugPrint('[ConnectionProvider] 已连接到服务端: $host:$port');
    } catch (e) {
      _lastError = '连接服务端失败: $e';
      _mode = ConnectionMode.disconnected;
      if (hadLocalBackend) {
        await connectToBundledLocal();
        _lastError = '连接服务端失败，已恢复本机服务端: $e';
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
    _localLanIps = [];
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
    _localLanIps = [];
    _lastError ??= '服务端连接已断开';
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

class RemoteConnectionRecord {
  final String host;
  final int port;
  final DateTime updatedAt;

  const RemoteConnectionRecord({
    required this.host,
    required this.port,
    required this.updatedAt,
  });

  factory RemoteConnectionRecord.fromJson(Map<String, dynamic> json) {
    return RemoteConnectionRecord(
      host: json['host'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 0,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get label => '$host:$port';
}
