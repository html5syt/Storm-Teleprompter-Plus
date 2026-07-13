import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../utils/constants.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

@visibleForTesting
Directory? appDataDirectoryOverride;

/// 返回当前平台使用的持久数据根目录。
///
/// 桌面版本是可移植的：数据与可执行文件捆绑在一起。
/// 移动版本继续使用平台的应用支持目录。
Future<Directory> getAppDataDirectory() async {
  final override = appDataDirectoryOverride;
  if (override != null) {
    if (!await override.exists()) await override.create(recursive: true);
    return override;
  }

  final Directory directory;
  if (_isDesktop) {
    var executableRoot = File(Platform.resolvedExecutable).parent;
    if (Platform.isMacOS) {
      final contentsDirectory = executableRoot.parent;
      final appBundle = contentsDirectory.parent;
      if (p.extension(appBundle.path).toLowerCase() == '.app') {
        executableRoot = appBundle.parent;
      }
    }
    directory = Directory(
      p.join(executableRoot.path, StorageConstants.desktopDataDirectoryName),
    );
  } else {
    directory = await getApplicationSupportDirectory();
  }

  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  return directory;
}
