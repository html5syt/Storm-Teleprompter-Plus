/// 按平台选择应用键值存储实现。
export 'system/app_preferences_shared.dart'
    if (dart.library.io) 'system/app_preferences_io.dart';
