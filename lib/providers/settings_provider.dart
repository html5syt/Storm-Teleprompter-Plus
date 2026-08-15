import 'package:flutter/material.dart';
import '../backend/ws_protocol.dart';
import '../models/app_settings.dart';
import 'connection_provider.dart';

class SettingsProvider with ChangeNotifier {
  AppSettings _settings = const AppSettings();
  bool _isLoading = false;

  ConnectionProvider? _connection;

  Map<String, dynamic> _articleOverrides = {};
  bool _articleOverridesActive = false;

  VoidCallback? _connectionListener;
  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;

  AppSettings get mergedSettings => _articleOverrides.isNotEmpty
      ? _settings.mergeOverrides(_articleOverrides)
      : _settings;

  Map<String, dynamic> get articleOverrides =>
      Map.unmodifiable(_articleOverrides);

  void bindConnection(ConnectionProvider connection) {
    if (_connection != null && _connectionListener != null) {
      _connection!.removeListener(_connectionListener!);
    }
    _connection = connection;
    _connectionListener = () {
      if (!connection.isConnected && !connection.canRetryRemoteConnection) {
        _articleOverrides = {};
        _articleOverridesActive = false;
        _isLoading = false;
        notifyListeners();
      }
    };
    connection.addListener(_connectionListener!);
  }

  void loadArticleOverrides(
    Map<String, dynamic>? overrides, {
    bool notify = true,
  }) {
    final next = _settings
        .mergeOverrides(Map<String, dynamic>.from(overrides ?? const {}))
        .toTeleprompterMap();
    final unchanged =
        _articleOverridesActive && _mapEquals(_articleOverrides, next);
    _articleOverridesActive = true;
    if (unchanged) return;
    _articleOverrides = next;
    if (notify) notifyListeners();
  }

  void applyRemoteTeleprompterSettings(Map<String, dynamic> settings) {
    final next = _settings.mergeOverrides(settings).toTeleprompterMap();
    final unchanged =
        _articleOverridesActive && _mapEquals(_articleOverrides, next);
    _articleOverridesActive = true;
    if (unchanged) return;
    _articleOverrides = next;
    notifyListeners();
  }

  void applyRemoteSyncedRuntimeSettings(Map<String, dynamic> settings) {
    var changed = false;
    if (settings['scrollMode'] case final String modeName) {
      final mode = ScrollMode.values.firstWhere(
        (value) => value.name == modeName,
        orElse: () => mergedSettings.scrollMode,
      );
      if (_articleOverrides['scrollMode'] != mode.name) {
        _articleOverrides['scrollMode'] = mode.name;
        changed = true;
      }
    }
    if (settings.containsKey('wpm')) {
      final value = settings['wpm'];
      if (value is num) {
        final next = value.toInt();
        if (_articleOverrides['wpm'] != next) {
          _articleOverrides['wpm'] = next;
          changed = true;
        }
      }
    }
    if (changed) notifyListeners();
  }

  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  void clearArticleOverrides() {
    if (!_articleOverridesActive && _articleOverrides.isEmpty) return;
    _articleOverridesActive = false;
    _articleOverrides = {};
    notifyListeners();
  }

  Future<void> _setAndSave({required Map<String, dynamic> overrideData}) async {
    if (_articleOverridesActive) {
      _articleOverrides.addAll(overrideData);
      notifyListeners();
    } else {
      _settings = _settings.mergeOverrides(overrideData);
      notifyListeners();
      await _saveSettings();
    }
    _syncTeleprompterSettingsToBackend();
  }

  void _syncTeleprompterSettingsToBackend() {
    final connection = _connection;
    if (connection == null || !connection.isConnected || !connection.isLocal) {
      return;
    }
    connection.send(
      WsMessage(
        type: WsMessageType.teleprompterSettingsUpdate,
        data: {'settings': mergedSettings.toTeleprompterMap()},
      ),
    );
  }

  Future<void> init() async {
    await loadSettings();
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_connection != null && _connection!.isConnected) {
        final response = await _connection!.request(WsMessageType.settingsGet);
        if (response.type == WsMessageType.settingsGetResponse) {
          _settings = AppSettings.fromJson(
            response.data['settings'] as Map<String, dynamic>,
          );
        }
      }
    } catch (e) {
      debugPrint('[SettingsProvider] 加载设置失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveSettings() async {
    try {
      if (_connection != null && _connection!.isConnected) {
        _connection!.request(
          WsMessageType.settingsSave,
          data: {'settings': _settings.toJson()},
        );
      }
    } catch (e) {
      debugPrint('[SettingsProvider] 保存设置失败: $e');
    }
  }

  Future<void> setFontSize(double fontSize) async {
    await _setAndSave(overrideData: {'fontSize': fontSize});
  }

  Future<void> setLineHeight(double lineHeight) async {
    await _setAndSave(overrideData: {'lineHeight': lineHeight});
  }

  Future<void> setScrollMode(ScrollMode mode) async {
    if (_articleOverridesActive) {
      _articleOverrides['scrollMode'] = mode.name;
      notifyListeners();
    } else {
      _settings = _settings.copyWith(scrollMode: mode);
      notifyListeners();
      await _saveSettings();
    }
    _syncTeleprompterSettingsToBackend();
  }

  Future<void> setWpm(int wpm) async {
    await _setAndSave(overrideData: {'wpm': wpm < 0 ? 0 : wpm});
  }

  Future<void> toggleMirrorMode() async {
    await _setAndSave(overrideData: {'mirrorMode': !mergedSettings.mirrorMode});
  }

  Future<void> toggleFullScreenMode() async {
    _settings = _settings.copyWith(fullScreenMode: !_settings.fullScreenMode);
    notifyListeners();
    await _saveSettings();
  }

  Future<void> setFullScreenMode(bool value) async {
    _settings = _settings.copyWith(fullScreenMode: value);
    notifyListeners();
    await _saveSettings();
  }

  Future<void> toggleAutoHideUI() async {
    _settings = _settings.copyWith(autoHideUI: !_settings.autoHideUI);
    notifyListeners();
    await _saveSettings();
  }

  Future<void> setAutoHideDelay(int seconds) async {
    _settings = _settings.copyWith(autoHideDelaySeconds: seconds);
    notifyListeners();
    await _saveSettings();
  }

  Future<void> setAsrModel(String id, String name) async {
    _settings = _settings.copyWith(asrModelId: id, asrModelName: name);
    notifyListeners();
    await _saveSettings();
  }

  Future<void> clearAsrModel() => setAsrModel('', '');

  Future<void> setAsrInputDevice(String id, String name) async {
    _settings = _settings.copyWith(
      asrInputDeviceId: id,
      asrInputDeviceName: name,
    );
    notifyListeners();
    await _saveSettings();
  }

  Future<void> setUiPrimaryColor(int hexColor) async {
    _settings = _settings.copyWith(uiPrimaryColor: hexColor);
    notifyListeners();
    await _saveSettings();
  }

  Future<void> setTeleprompterBgColor(int hexColor) async {
    await _setAndSave(overrideData: {'teleprompterBgColor': hexColor});
  }

  Future<void> setPaddingX(double value) async {
    await _setAndSave(overrideData: {'paddingX': value});
  }

  Future<void> setReadingLineOffset(double value) async {
    await _setAndSave(overrideData: {'readingLineOffset': value});
  }

  Future<void> setProgressInfoSizeRatio(double value) async {
    await _setAndSave(overrideData: {'progressInfoSizeRatio': value});
  }

  Future<void> setAsrMirrorUrl(String url) async {
    _settings = _settings.copyWith(asrMirrorUrl: url);
    notifyListeners();
    await _saveSettings();
  }

  Future<void> setAsrAdvancedParameters({
    required int numThreads,
    required double rule1MinTrailingSilence,
    required double rule2MinTrailingSilence,
    required double rule3MinUtteranceLength,
    required bool useSystemProxy,
  }) async {
    _settings = _settings.copyWith(
      asrNumThreads: numThreads.clamp(0, 64),
      asrRule1MinTrailingSilence: rule1MinTrailingSilence.clamp(0.1, 20),
      asrRule2MinTrailingSilence: rule2MinTrailingSilence.clamp(0.1, 20),
      asrRule3MinUtteranceLength: rule3MinUtteranceLength.clamp(1, 300),
      asrUseSystemProxy: useSystemProxy,
    );
    notifyListeners();
    await _saveSettings();
  }

  Future<void> setAppFontFamily(String fontFamily) async {
    _settings = _settings.copyWith(appFontFamily: fontFamily);
    notifyListeners();
    await _saveSettings();
  }

  Future<void> setTeleprompterFontFamily(String fontFamily) async {
    await _setAndSave(overrideData: {'teleprompterFontFamily': fontFamily});
  }

  Future<void> toggleGrayReadChars() async {
    await _setAndSave(
      overrideData: {'grayReadChars': !mergedSettings.grayReadChars},
    );
  }

  Future<void> setTextColor(int hexColor) async {
    await _setAndSave(overrideData: {'textColor': hexColor});
  }

  Future<void> setLetterSpacing(double value) async {
    await _setAndSave(overrideData: {'letterSpacing': value});
  }

  Future<void> toggleHighlightCurrentChar() async {
    await _setAndSave(
      overrideData: {
        'highlightCurrentChar': !mergedSettings.highlightCurrentChar,
      },
    );
  }

  Future<void> toggleDefaultBold() async {
    await _setAndSave(
      overrideData: {'defaultBold': !mergedSettings.defaultBold},
    );
  }

  Future<void> toggleUnderlineCurrentChar() async {
    await _setAndSave(
      overrideData: {
        'underlineCurrentChar': !mergedSettings.underlineCurrentChar,
      },
    );
  }

  Future<void> setReadingAreaBorderWidth(double value) async {
    await _setAndSave(overrideData: {'readingAreaBorderWidth': value});
  }

  Future<void> toggleProgressShowTime() async {
    await _setAndSave(
      overrideData: {'progressShowTime': !mergedSettings.progressShowTime},
    );
  }

  Future<void> toggleProgressShowPercentage() async {
    await _setAndSave(
      overrideData: {
        'progressShowPercentage': !mergedSettings.progressShowPercentage,
      },
    );
  }

  Future<void> toggleProgressShowSpeed() async {
    await _setAndSave(
      overrideData: {'progressShowSpeed': !mergedSettings.progressShowSpeed},
    );
  }

  Future<void> toggleProgressShowCurrentTime() async {
    await _setAndSave(
      overrideData: {
        'progressShowCurrentTime': !mergedSettings.progressShowCurrentTime,
      },
    );
  }

  Future<void> setAppBrightnessMode(AppBrightnessMode mode) async {
    _settings = _settings.copyWith(appBrightnessMode: mode);
    notifyListeners();
    await _saveSettings();
  }

  Future<void> resetAllSettings() async {
    _settings = const AppSettings();
    notifyListeners();
    try {
      if (_connection != null && _connection!.isConnected) {
        _connection!.request(WsMessageType.settingsReset);
      }
    } catch (e) {
      debugPrint('[SettingsProvider] 重置设置失败: $e');
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    await _saveSettings();
  }

  @override
  void dispose() {
    if (_connection != null && _connectionListener != null) {
      _connection!.removeListener(_connectionListener!);
    }
    super.dispose();
  }
}
