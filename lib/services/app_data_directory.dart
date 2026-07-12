import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

@visibleForTesting
Directory? appDataDirectoryOverride;

/// Returns the persistent data root used by the current platform.
///
/// Desktop builds are portable: data lives beside the executable bundle.
/// Mobile builds continue to use the platform application-support directory.
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
    directory = Directory(p.join(executableRoot.path, 'app_data'));
  } else {
    directory = await getApplicationSupportDirectory();
  }

  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  return directory;
}
