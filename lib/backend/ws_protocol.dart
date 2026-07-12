import 'dart:convert';

/// WebSocket 消息类型枚举
///
/// 定义前后端之间所有可能的消息类型。
/// 命名规则：`domain:action`
enum WsMessageType {
  // ─── 稿件管理 ──────────────────────────────────────────
  articleList('article:list'),
  articleListResponse('article:list_response'),
  articleGet('article:get'),
  articleGetResponse('article:get_response'),
  articleCreate('article:create'),
  articleCreateResponse('article:create_response'),
  articleUpdate('article:update'),
  articleUpdateResponse('article:update_response'),
  articleDelete('article:delete'),
  articleDeleteResponse('article:delete_response'),
  articleImport('article:import'),
  articleImportResponse('article:import_response'),
  articleExport('article:export'),
  articleExportResponse('article:export_response'),

  // ─── 文件夹管理 ────────────────────────────────────────
  folderList('folder:list'),
  folderListResponse('folder:list_response'),
  folderCreate('folder:create'),
  folderCreateResponse('folder:create_response'),
  folderRename('folder:rename'),
  folderRenameResponse('folder:rename_response'),
  folderDelete('folder:delete'),
  folderDeleteResponse('folder:delete_response'),
  folderMoveArticle('folder:move_article'),
  folderMoveArticleResponse('folder:move_article_response'),

  // ─── 设置 ──────────────────────────────────────────────
  settingsGet('settings:get'),
  settingsGetResponse('settings:get_response'),
  settingsSave('settings:save'),
  settingsSaveResponse('settings:save_response'),
  settingsReset('settings:reset'),
  settingsResetResponse('settings:reset_response'),

  appBackupExport('app:backup_export'),
  appBackupExportResponse('app:backup_export_response'),
  appBackupRestore('app:backup_restore'),
  appBackupRestoreResponse('app:backup_restore_response'),

  // ─── 提词器会话 ────────────────────────────────────────
  teleprompterStartSession('teleprompter:start_session'),
  teleprompterStartSessionResponse('teleprompter:start_session_response'),
  teleprompterEndSession('teleprompter:end_session'),
  teleprompterEndSessionResponse('teleprompter:end_session_response'),
  teleprompterSync('teleprompter:sync'),
  teleprompterSettingsUpdate('teleprompter:settings_update'),

  // ─── ASR 语音识别 ──────────────────────────────────────
  asrStart('asr:start'),
  asrStartResponse('asr:start_response'),
  asrPause('asr:pause'),
  asrPauseResponse('asr:pause_response'),
  asrResult('asr:result'),
  asrStatus('asr:status'),

  // ─── 连接管理 ──────────────────────────────────────────
  connectionInfo('connection:info'),
  connectionPing('connection:ping'),
  connectionPong('connection:pong'),
  connectionDevices('connection:devices'),

  // ─── 通用 ──────────────────────────────────────────────
  error('error'),
  unknown('unknown');

  final String value;
  const WsMessageType(this.value);

  /// 从字符串解析消息类型
  static WsMessageType fromString(String value) {
    return WsMessageType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => WsMessageType.unknown,
    );
  }
}

/// WebSocket 消息基类
///
/// 所有 WS 消息的统一格式。
class WsMessage {
  final WsMessageType type;
  final Map<String, dynamic> data;
  final String? id; // 请求-响应配对 ID

  const WsMessage({required this.type, this.data = const {}, this.id});

  /// 从 JSON 字符串解析
  factory WsMessage.fromJson(Map<String, dynamic> json) {
    return WsMessage(
      type: WsMessageType.fromString(json['type'] as String? ?? ''),
      data: json['data'] as Map<String, dynamic>? ?? {},
      id: json['id'] as String?,
    );
  }

  /// 从原始字符串解析
  factory WsMessage.fromString(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return WsMessage.fromJson(json);
    } catch (_) {
      return const WsMessage(type: WsMessageType.unknown);
    }
  }

  /// 序列化为 JSON Map
  Map<String, dynamic> toJson() {
    return {'type': type.value, 'data': data, if (id != null) 'id': id};
  }

  /// 序列化为 JSON 字符串
  String encode() => jsonEncode(toJson());

  @override
  String toString() => 'WsMessage(${type.value}, id=$id)';
}

/// 请求 ID 生成器
class RequestIdGenerator {
  static int _counter = 0;

  static String next() {
    _counter++;
    return 'req_${DateTime.now().millisecondsSinceEpoch}_$_counter';
  }
}
