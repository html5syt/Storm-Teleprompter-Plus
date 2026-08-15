import 'dart:convert';

enum WsMessageType {
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

  folderList('folder:list'),
  folderListResponse('folder:list_response'),
  folderCreate('folder:create'),
  folderCreateResponse('folder:create_response'),
  folderRename('folder:rename'),
  folderRenameResponse('folder:rename_response'),
  folderDelete('folder:delete'),
  folderDeleteResponse('folder:delete_response'),
  folderMove('folder:move'),
  folderMoveResponse('folder:move_response'),
  folderCopy('folder:copy'),
  folderCopyResponse('folder:copy_response'),
  folderMoveArticle('folder:move_article'),
  folderMoveArticleResponse('folder:move_article_response'),

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

  teleprompterStartSession('teleprompter:start_session'),
  teleprompterStartSessionResponse('teleprompter:start_session_response'),
  teleprompterEndSession('teleprompter:end_session'),
  teleprompterEndSessionResponse('teleprompter:end_session_response'),
  teleprompterSync('teleprompter:sync'),
  teleprompterSettingsUpdate('teleprompter:settings_update'),

  asrStart('asr:start'),
  asrStartResponse('asr:start_response'),
  asrPause('asr:pause'),
  asrPauseResponse('asr:pause_response'),
  asrResult('asr:result'),
  asrStatus('asr:status'),

  connectionInfo('connection:info'),
  connectionPing('connection:ping'),
  connectionPong('connection:pong'),
  connectionDevices('connection:devices'),

  error('error'),
  unknown('unknown');

  final String value;
  const WsMessageType(this.value);

  static WsMessageType fromString(String value) {
    return WsMessageType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => WsMessageType.unknown,
    );
  }
}

class WsMessage {
  final WsMessageType type;
  final Map<String, dynamic> data;
  final String? id; 

  const WsMessage({required this.type, this.data = const {}, this.id});

  factory WsMessage.fromJson(Map<String, dynamic> json) {
    return WsMessage(
      type: WsMessageType.fromString(json['type'] as String? ?? ''),
      data: json['data'] as Map<String, dynamic>? ?? {},
      id: json['id'] as String?,
    );
  }

  factory WsMessage.fromString(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return WsMessage.fromJson(json);
    } catch (_) {
      return const WsMessage(type: WsMessageType.unknown);
    }
  }

  Map<String, dynamic> toJson() {
    return {'type': type.value, 'data': data, if (id != null) 'id': id};
  }

  String encode() => jsonEncode(toJson());

  @override
  String toString() => 'WsMessage(${type.value}, id=$id)';
}

class RequestIdGenerator {
  static int _counter = 0;

  static String next() {
    _counter++;
    return 'req_${DateTime.now().millisecondsSinceEpoch}_$_counter';
  }
}
