import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';

/// 应用设置状态管理
class SettingsProvider with ChangeNotifier {
  AppSettings _settings = const AppSettings();
  bool _isLoading = false;
  StorageService? _storage;

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;

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
    _settings = _settings.copyWith(fontSize: fontSize);
    notifyListeners();
    await _saveSettings();
  }

  /// 更新行高
  Future<void> setLineHeight(double lineHeight) async {
    _settings = _settings.copyWith(lineHeight: lineHeight);
    notifyListeners();
    await _saveSettings();
  }

  /// 更新滚动模式
  Future<void> setScrollMode(ScrollMode mode) async {
    _settings = _settings.copyWith(scrollMode: mode);
    notifyListeners();
    await _saveSettings();
  }

  /// 更新 WPM
  Future<void> setWpm(int wpm) async {
    _settings = _settings.copyWith(wpm: wpm);
    notifyListeners();
    await _saveSettings();
  }

  /// 切换镜像模式
  Future<void> toggleMirrorMode() async {
    _settings = _settings.copyWith(mirrorMode: !_settings.mirrorMode);
    notifyListeners();
    await _saveSettings();
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

  /// 批量更新设置
  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    await _saveSettings();
  }
}
