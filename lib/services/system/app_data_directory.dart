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
