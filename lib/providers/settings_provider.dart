import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';

/// 应用设置状态管理
class SettingsProvider with ChangeNotifier {
  AppSettings _settings = const AppSettings();
  bool _isLoading = false;
  StorageService? _storage;

  // ─── 稿件覆盖设置 ──────────────────────────────────────
  Map<String, dynamic> _articleOverrides = {};

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;

  /// 合并稿件覆盖后的设置（提词器页面使用）
  AppSettings get mergedSettings => _articleOverrides.isNotEmpty
      ? _settings.mergeOverrides(_articleOverrides)
      : _settings;

  /// 当前活跃的稿件覆盖
  Map<String, dynamic> get articleOverrides =>
      Map.unmodifiable(_articleOverrides);

  /// 加载稿件覆盖设置
  void loadArticleOverrides(Map<String, dynamic>? overrides) {
    _articleOverrides = overrides ?? {};
    notifyListeners();
  }

  /// 清除稿件覆盖设置
  void clearArticleOverrides() {
    if (_articleOverrides.isNotEmpty) {
      _articleOverrides = {};
      notifyListeners();
    }
  }

  /// 内部辅助：在当前稿件覆盖激活时写入覆盖层，否则写入全局设置
  Future<void> _setAndSave({required Map<String, dynamic> overrideData}) async {
    if (_articleOverrides.isNotEmpty) {
      // 稿件覆盖模式：写入覆盖层，不保存到全局
      _articleOverrides.addAll(overrideData);
      notifyListeners();
    } else {
      // 全局模式：更新全局设置并保存
      // 通过逐个应用 copyWith 来更新
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
          fontFamily: overrideData['fontFamily'] as String,
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
      _settings = updated;
      notifyListeners();
      await _saveSettings();
    }
  }

  /// 初始化并加载设置
  Future<void> init() async {
    _storage = await StorageService.getInstance();
    await loadSettings();
  }

  /// 加载设置
  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      _settings = await _storage!.loadSettings();
    } catch (e) {
      debugPrint('[SettingsProvider] 加载设置失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    try {
      await _storage!.saveSettings(_settings);
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
    if (_articleOverrides.isNotEmpty) {
      _articleOverrides['scrollMode'] = mode.name;
      notifyListeners();
    } else {
      _settings = _settings.copyWith(scrollMode: mode);
      notifyListeners();
      await _saveSettings();
    }
  }

  /// 更新 WPM
  Future<void> setWpm(int wpm) async {
    await _setAndSave(overrideData: {'wpm': wpm});
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

  /// 更新正文字体
  Future<void> setFontFamily(String fontFamily) async {
    await _setAndSave(overrideData: {'fontFamily': fontFamily});
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

  /// 完全重置所有设置为默认值
  Future<void> resetAllSettings() async {
    _settings = const AppSettings();
    notifyListeners();
    await _saveSettings();
  }

  /// 批量更新设置
  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    await _saveSettings();
  }
}
