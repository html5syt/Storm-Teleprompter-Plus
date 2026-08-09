import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../utils/constants.dart';

bool get _usesPortableDesktopDataDirectory => usesPortableDesktopDataDirectory(
  isWindows: Platform.isWindows,
  isLinux: Platform.isLinux,
  isMacOS: Platform.isMacOS,
);

@visibleForTesting
bool usesPortableDesktopDataDirectory({
  required bool isWindows,
  required bool isLinux,
  required bool isMacOS,
}) => !isMacOS && (isWindows || isLinux);

@visibleForTesting
Directory? appDataDirectoryOverride;

/// 返回当前平台使用的持久数据根目录。
///
/// Windows 和 Linux 桌面版本保持可移植：数据与可执行文件捆绑在一起。
/// macOS 以及移动版本使用平台的应用支持目录。macOS 的 .app 包可能位于
/// /Applications 或 App Translocation 的只读位置，不能存放可变数据。
Future<Directory> getAppDataDirectory() async {
  final override = appDataDirectoryOverride;
  if (override != null) {
    if (!await override.exists()) await override.create(recursive: true);
    return override;
  }

  final Directory directory;
  if (_usesPortableDesktopDataDirectory) {
    final executableRoot = File(Platform.resolvedExecutable).parent;
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
