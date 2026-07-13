/// 按平台选择应用退出实现。
export 'system/app_exit_stub.dart'
    if (dart.library.io) 'system/app_exit_io.dart';
