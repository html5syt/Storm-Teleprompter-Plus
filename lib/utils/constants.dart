abstract final class AppConstants {
  AppConstants._();

  static const String displayName = '飓风提词器 Plus';
  static const String englishName = 'Storm Teleprompter+';
  static const String chineseAboutDescription =
      '基于 Flutter 构建的跨平台智能提词器，支持富文本稿件管理、自动滚动、离线语音识别、分光镜镜像显示，以及局域网多设备同步。';
  static const String englishAboutDescription =
      'A cross-platform teleprompter, featuring offline speech recognition, LAN device synchronization and more.';
}

abstract final class StorageConstants {
  StorageConstants._();

  static const String settingsKey = 'app_settings';
  static const String articlesKey = 'articles_data';
  static const String foldersKey = 'folders_data';
  static const String remoteConnectionHistoryKey = 'remote_connection_history';
  static const String ignoredUpdateVersionKey = 'ignored_update_version';

  static const String desktopDataDirectoryName = 'app_data';
  static const String desktopPreferencesFileName = 'application.json';
  static const String logDirectoryName = 'logs';
  static const String startupLogFilePrefix = 'storm-teleprompter-startup-';
  static const int maxStartupLogFiles = 7;
}

abstract final class NetworkConstants {
  NetworkConstants._();

  static const String loopbackHost = 'localhost';
  static const int maxRemoteConnectionHistory = 5;
}

abstract final class LayoutConstants {
  LayoutConstants._();

  static const double compactBreakpoint = 600;
}

abstract final class TeleprompterConstants {
  TeleprompterConstants._();

  static const double mobileHorizontalPadding = 16;
  static const double desktopHorizontalPadding = 64;

  static const double readingLineRatioMobile = 0.30;
  static const double readingLineRatioDesktop = 0.25;

  static const double topPaddingVh = 30.0;
  static const double bottomPaddingVh = 80.0;

  static const Duration articleSettingsSaveDebounce = Duration(
    milliseconds: 350,
  );

  static const List<int> speedPresets = [
    80,
    160,
    240,
    260,
    275,
    295,
    320,
    400,
    450,
  ];
}
