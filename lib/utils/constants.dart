/// 应用标识。
abstract final class AppConstants {
  AppConstants._();

  static const String displayName = '飓风提词器 Plus';
  static const String englishName = 'Storm Teleprompter+';
}

/// 本地持久化约定。
///
/// 键名必须保持稳定，否则现有稿件和设置将无法读取；文件和目录名称用于桌面端
/// 自包含数据模式。
abstract final class StorageConstants {
  StorageConstants._();

  static const String settingsKey = 'app_settings';
  static const String articlesKey = 'articles_data';
  static const String foldersKey = 'folders_data';
  static const String remoteConnectionHistoryKey = 'remote_connection_history';
  static const String ignoredUpdateVersionKey = 'ignored_update_version';

  static const String desktopDataDirectoryName = 'app_data';
  static const String desktopPreferencesFileName = 'application.json';
}

/// 网络连接的公共约定。
abstract final class NetworkConstants {
  NetworkConstants._();

  static const String loopbackHost = 'localhost';
  static const int maxRemoteConnectionHistory = 5;
}

/// 跨页面共享的响应式布局断点。
abstract final class LayoutConstants {
  LayoutConstants._();

  static const double compactBreakpoint = 600;
}

/// 提词器布局与交互中跨组件共享的参数。
///
/// 这些值同时被正文层、阅读区域框和滚动进度计算使用，必须保持一致。
abstract final class TeleprompterConstants {
  TeleprompterConstants._();

  static const double mobileHorizontalPadding = 16;
  static const double desktopHorizontalPadding = 64;

  static const double readingLineRatioMobile = 0.30;
  static const double readingLineRatioDesktop = 0.25;

  /// 首尾空气垫占视口高度的百分比。
  static const double topPaddingVh = 30.0;
  static const double bottomPaddingVh = 80.0;

  static const Duration articleSettingsSaveDebounce = Duration(
    milliseconds: 350,
  );

  static const List<int> speedPresets = [
    60,
    80,
    100,
    120,
    150,
    180,
    200,
    250,
    300,
    400,
  ];
}
