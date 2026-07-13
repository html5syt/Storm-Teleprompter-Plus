/// 按平台选择本地 Git 版本读取实现。
export 'system/git_version_stub.dart'
    if (dart.library.io) 'system/git_version_io.dart';
