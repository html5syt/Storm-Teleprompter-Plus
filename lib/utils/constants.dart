/// 应用常量定义
class AppConstants {
  AppConstants._();

  /// 应用名称
  static const String appName = '飓风提词器 Plus';

  /// 应用版本
  static const String appVersion = '1.0.0';

  /// WPM 范围（自动滚动速度）
  static const int minWpm = 30;
  static const int maxWpm = 450;

  /// 阅读线位置比例
  static const double readingLineRatioMobile = 0.30;
  static const double readingLineRatioDesktop = 0.25;

  /// 空气垫高度（用于首尾行滚动到阅读线）
  static const double topPaddingVh = 30.0;
  static const double bottomPaddingVh = 80.0;

  /// ASR 模型下载镜像
  static const String defaultModelMirror =
      'https://hf-mirror.com/csukuangfj/sherpa-onnx-paraformer-zh-2023-09-14/resolve/main/';
  static const String defaultModelOriginal =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/';

  /// SharedPreferences 键名
  static const String prefKeySettings = 'app_settings';
  static const String prefKeyArticles = 'articles_data';
  static const String prefKeyFolders = 'folders_data';
}
