import 'dart:convert';
import '../models/app_settings.dart';
import '../services/app_preferences.dart';
import '../utils/constants.dart';
import 'ws_protocol.dart';
import 'ws_server.dart';

/// 设置管理后端服务
///
/// 处理应用设置和提词器设置的读取、保存和重置。
class SettingsService {
  late AppPreferences _prefs;

  /// 初始化存储
  Future<void> init() async {
    _prefs = await AppPreferences.getInstance();
  }

  /// 注册消息处理器到 WsServer
  void registerHandlers(WsServer server) {
    server.requests.listen((request) {
      switch (request.message.type) {
        case WsMessageType.settingsGet:
          _handleSettingsGet(server, request);
          break;
        case WsMessageType.settingsSave:
          _handleSettingsSave(server, request);
          break;
        case WsMessageType.settingsReset:
          _handleSettingsReset(server, request);
          break;
        default:
          break;
      }
    });
  }

  Future<void> _handleSettingsGet(WsServer server, WsRequest request) async {
    final settings = await loadSettings();
    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.settingsGetResponse,
        id: request.message.id,
        data: {'settings': settings.toJson()},
      ),
    );
  }

  Future<void> _handleSettingsSave(WsServer server, WsRequest request) async {
    final settingsJson =
        request.message.data['settings'] as Map<String, dynamic>?;
    if (settingsJson == null) {
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.error,
          id: request.message.id,
          data: {'message': '缺少设置数据'},
        ),
      );
      return;
    }

    try {
      final settings = AppSettings.fromJson(settingsJson);
      await saveSettings(settings);
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.settingsSaveResponse,
          id: request.message.id,
          data: {'success': true},
        ),
      );
    } catch (e) {
      server.respond(
        request.clientId,
        WsMessage(
          type: WsMessageType.error,
          id: request.message.id,
          data: {'message': '保存设置失败: $e'},
        ),
      );
    }
  }

  Future<void> _handleSettingsReset(WsServer server, WsRequest request) async {
    final settings = const AppSettings();
    await saveSettings(settings);
    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.settingsResetResponse,
        id: request.message.id,
        data: {'settings': settings.toJson(), 'success': true},
      ),
    );
  }

  // ─── 底层存储操作 ───────────────────────────────────────

  /// 加载应用设置
  Future<AppSettings> loadSettings() async {
    final jsonStr = _prefs.getString(StorageConstants.settingsKey);
    if (jsonStr == null || jsonStr.isEmpty) return const AppSettings();

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return const AppSettings();
    }
  }

  /// 保存应用设置
  Future<void> saveSettings(AppSettings settings) async {
    final jsonStr = jsonEncode(settings.toJson());
    await _prefs.setString(StorageConstants.settingsKey, jsonStr);
  }
}
