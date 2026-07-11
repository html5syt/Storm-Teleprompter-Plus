import 'package:flutter/material.dart';
import '../backend/ws_protocol.dart';
import '../models/app_settings.dart';
import 'connection_provider.dart';

/// 应用设置状态管理（前端）
///
/// 通过 WebSocket 与后端通信，管理应用设置的读取、保存。
/// 同时支持稿件级别的设置覆盖（提词器设置与应用设置分离）。
class SettingsProvider with ChangeNotifier {
  AppSettings _settings = const AppSettings();
  bool _isLoading = false;

  ConnectionProvider? _connection;

  // ─── 稿件覆盖设置 ──────────────────────────────────────
  Map<String, dynamic> _articleOverrides = {};
  bool _articleOverridesActive = false;

  VoidCallback? _connectionListener;
  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;

  /// 合并稿件覆盖后的设置（提词器页面使用）
  AppSettings get mergedSettings => _articleOverrides.isNotEmpty
      ? _settings.mergeOverrides(_articleOverrides)
      : _settings;

  /// 当前活跃的稿件覆盖
  Map<String, dynamic> get articleOverrides =>
      Map.unmodifiable(_articleOverrides);

  /// 绑定连接
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

  /// 加载稿件覆盖设置
  void loadArticleOverrides(
    Map<String, dynamic>? overrides, {
    bool notify = true,
  }) {
    final next = Map<String, dynamic>.from(overrides ?? const {});
    final unchanged =
        _articleOverridesActive && _mapEquals(_articleOverrides, next);
    _articleOverridesActive = true;
    if (unchanged) return;
    _articleOverrides = next;
    if (notify) notifyListeners();
  }

  void applyRemoteTeleprompterSettings(Map<String, dynamic> settings) {
    final next = Map<String, dynamic>.from(settings);
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

  /// 清除稿件覆盖设置
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

  /// 内部辅助：在当前稿件覆盖激活时写入覆盖层，否则写入全局设置
  Future<void> _setAndSave({required Map<String, dynamic> overrideData}) async {
    if (_articleOverridesActive) {
      // 稿件覆盖模式：写入覆盖层，不保存到全局
      _articleOverrides.addAll(overrideData);
      notifyListeners();
    } else {
      // 全局模式：更新全局设置并保存
      var updated = _settings;
      if (overrideData.containsKey('fontSize')) {
        updated = updated.copyWith(
          fontSize: (overrideData['fontSize'] as num).toDouble(),
        );
      }
      if (overrideData.containsKey('lineHeight')) {
        updated = updated.copyWith(
          lineHeight: (overrideData['lineHeight'] as num).toDouble(),
        );
      }
      if (overrideData.containsKey('wpm')) {
        updated = updated.copyWith(wpm: overrideData['wpm'] as int);
      }
      if (overrideData.containsKey('mirrorMode')) {
        updated = updated.copyWith(
          mirrorMode: overrideData['mirrorMode'] as bool,
        );
      }
      if (overrideData.containsKey('paddingX')) {
        updated = updated.copyWith(
          paddingX: (overrideData['paddingX'] as num).toDouble(),
        );
      }
      if (overrideData.containsKey('readingLineOffset')) {
        updated = updated.copyWith(
          readingLineOffset: (overrideData['readingLineOffset'] as num)
              .toDouble(),
        );
      }
      if (overrideData.containsKey('highlightCurrentChar')) {
        updated = updated.copyWith(
          highlightCurrentChar: overrideData['highlightCurrentChar'] as bool,
        );
      }
      if (overrideData.containsKey('defaultBold')) {
        updated = updated.copyWith(
          defaultBold: overrideData['defaultBold'] as bool,
        );
      }
      if (overrideData.containsKey('progressInfoSizeRatio')) {
        updated = updated.copyWith(
          progressInfoSizeRatio: (overrideData['progressInfoSizeRatio'] as num)
              .toDouble(),
        );
      }
      if (overrideData.containsKey('fontFamily')) {
        updated = updated.copyWith(
          teleprompterFontFamily: overrideData['fontFamily'] as String,
        );
      }
      if (overrideData.containsKey('teleprompterFontFamily')) {
        updated = updated.copyWith(
          teleprompterFontFamily:
              overrideData['teleprompterFontFamily'] as String,
        );
      }
      if (overrideData.containsKey('grayReadChars')) {
        updated = updated.copyWith(
          grayReadChars: overrideData['grayReadChars'] as bool,
        );
      }
      if (overrideData.containsKey('textColor')) {
        updated = updated.copyWith(textColor: overrideData['textColor'] as int);
      }
      if (overrideData.containsKey('letterSpacing')) {
        updated = updated.copyWith(
          letterSpacing: (overrideData['letterSpacing'] as num).toDouble(),
        );
      }
      if (overrideData.containsKey('teleprompterBgColor')) {
        updated = updated.copyWith(
          teleprompterBgColor: overrideData['teleprompterBgColor'] as int,
        );
      }
      if (overrideData.containsKey('underlineCurrentChar')) {
        updated = updated.copyWith(
          underlineCurrentChar: overrideData['underlineCurrentChar'] as bool,
        );
      }
      if (overrideData.containsKey('readingAreaBorderWidth')) {
        updated = updated.copyWith(
          readingAreaBorderWidth:
              (overrideData['readingAreaBorderWidth'] as num).toDouble(),
        );
      }
      if (overrideData.containsKey('progressShowTime')) {
        updated = updated.copyWith(
          progressShowTime: overrideData['progressShowTime'] as bool,
        );
      }
      if (overrideData.containsKey('progressShowPercentage')) {
        updated = updated.copyWith(
          progressShowPercentage:
              overrideData['progressShowPercentage'] as bool,
        );
      }
      if (overrideData.containsKey('progressShowSpeed')) {
        updated = updated.copyWith(
          progressShowSpeed: overrideData['progressShowSpeed'] as bool,
        );
      }
      if (overrideData.containsKey('progressShowCurrentTime')) {
        updated = updated.copyWith(
          progressShowCurrentTime:
              overrideData['progressShowCurrentTime'] as bool,
        );
      }
      if (overrideData.containsKey('appBrightnessMode')) {
        updated = updated.copyWith(
          appBrightnessMode:
              overrideData['appBrightnessMode'] as AppBrightnessMode,
        );
      }
      _settings = updated;
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

  /// 初始化并加载设置
  Future<void> init() async {
    await loadSettings();
  }

  /// 从后端加载设置
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

  /// 保存设置到后端
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

  /// 更新字体大小
  Future<void> setFontSize(double fontSize) async {
    await _setAndSave(overrideData: {'fontSize': fontSize});
  }

  /// 更新行高
  Future<void> setLineHeight(double lineHeight) async {
    await _setAndSave(overrideData: {'lineHeight': lineHeight});
  }

  /// 更新滚动模式
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

  /// 更新 WPM
  Future<void> setWpm(int wpm) async {
    await _setAndSave(overrideData: {'wpm': wpm < 0 ? 0 : wpm});
  }

  /// 切换镜像模式
  Future<void> toggleMirrorMode() async {
    await _setAndSave(overrideData: {'mirrorMode': !mergedSettings.mirrorMode});
  }

  /// 切换全屏模式
  Future<void> toggleFullScreenMode() async {
    _settings = _settings.copyWith(fullScreenMode: !_settings.fullScreenMode);
    notifyListeners();
    await _saveSettings();
  }

  /// 设置全屏模式
  Future<void> setFullScreenMode(bool value) async {
    _settings = _settings.copyWith(fullScreenMode: value);
    notifyListeners();
    await _saveSettings();
  }

  /// 切换自动隐藏 UI
  Future<void> toggleAutoHideUI() async {
    _settings = _settings.copyWith(autoHideUI: !_settings.autoHideUI);
    notifyListeners();
    await _saveSettings();
  }

  /// 设置自动隐藏延迟
  Future<void> setAutoHideDelay(int seconds) async {
    _settings = _settings.copyWith(autoHideDelaySeconds: seconds);
    notifyListeners();
    await _saveSettings();
  }

  /// 设置 ASR 模型信息
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

  /// 更新主题色
  Future<void> setUiPrimaryColor(int hexColor) async {
    _settings = _settings.copyWith(uiPrimaryColor: hexColor);
    notifyListeners();
    await _saveSettings();
  }

  /// 更新提词器背景色
  Future<void> setTeleprompterBgColor(int hexColor) async {
    await _setAndSave(overrideData: {'teleprompterBgColor': hexColor});
  }

  /// 更新水平边距
  Future<void> setPaddingX(double value) async {
    await _setAndSave(overrideData: {'paddingX': value});
  }

  /// 更新阅读线偏移
  Future<void> setReadingLineOffset(double value) async {
    await _setAndSave(overrideData: {'readingLineOffset': value});
  }

  /// 更新进度条提示字号比例
  Future<void> setProgressInfoSizeRatio(double value) async {
    await _setAndSave(overrideData: {'progressInfoSizeRatio': value});
  }

  /// 更新 ASR 镜像 URL
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

  /// 更新应用 UI 字体
  Future<void> setAppFontFamily(String fontFamily) async {
    _settings = _settings.copyWith(appFontFamily: fontFamily);
    notifyListeners();
    await _saveSettings();
  }

  /// 更新提词器正文字体
  Future<void> setTeleprompterFontFamily(String fontFamily) async {
    await _setAndSave(overrideData: {'teleprompterFontFamily': fontFamily});
  }

  /// 切换已读字符变灰
  Future<void> toggleGrayReadChars() async {
    await _setAndSave(
      overrideData: {'grayReadChars': !mergedSettings.grayReadChars},
    );
  }

  /// 更新字体颜色
  Future<void> setTextColor(int hexColor) async {
    await _setAndSave(overrideData: {'textColor': hexColor});
  }

  /// 更新字间距
  Future<void> setLetterSpacing(double value) async {
    await _setAndSave(overrideData: {'letterSpacing': value});
  }

  /// 切换当前字高亮
  Future<void> toggleHighlightCurrentChar() async {
    await _setAndSave(
      overrideData: {
        'highlightCurrentChar': !mergedSettings.highlightCurrentChar,
      },
    );
  }

  /// 切换默认加粗
  Future<void> toggleDefaultBold() async {
    await _setAndSave(
      overrideData: {'defaultBold': !mergedSettings.defaultBold},
    );
  }

  /// 切换当前字下划线
  Future<void> toggleUnderlineCurrentChar() async {
    await _setAndSave(
      overrideData: {
        'underlineCurrentChar': !mergedSettings.underlineCurrentChar,
      },
    );
  }

  /// 更新阅读区域框边框粗细
  Future<void> setReadingAreaBorderWidth(double value) async {
    await _setAndSave(overrideData: {'readingAreaBorderWidth': value});
  }

  /// 切换进度条显示 - 已用时间
  Future<void> toggleProgressShowTime() async {
    await _setAndSave(
      overrideData: {'progressShowTime': !mergedSettings.progressShowTime},
    );
  }

  /// 切换进度条显示 - 进度百分比
  Future<void> toggleProgressShowPercentage() async {
    await _setAndSave(
      overrideData: {
        'progressShowPercentage': !mergedSettings.progressShowPercentage,
      },
    );
  }

  /// 切换进度条显示 - 滚动速度
  Future<void> toggleProgressShowSpeed() async {
    await _setAndSave(
      overrideData: {'progressShowSpeed': !mergedSettings.progressShowSpeed},
    );
  }

  /// 切换进度条显示 - 当前时间
  Future<void> toggleProgressShowCurrentTime() async {
    await _setAndSave(
      overrideData: {
        'progressShowCurrentTime': !mergedSettings.progressShowCurrentTime,
      },
    );
  }

  /// 设置局域网发布状态
  Future<void> setLanPublished(bool value) async {
    _settings = _settings.copyWith(isLanPublished: value);
    notifyListeners();
    await _saveSettings();
  }

  Future<void> setAppBrightnessMode(AppBrightnessMode mode) async {
    _settings = _settings.copyWith(appBrightnessMode: mode);
    notifyListeners();
    await _saveSettings();
  }

  /// 完全重置所有设置为默认值
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

  /// 批量更新设置
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
