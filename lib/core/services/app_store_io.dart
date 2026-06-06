import 'dart:convert';
import 'dart:io';

import '../models/app_models.dart';
import 'app_store_base.dart';

class FileAppStore extends AppStore {
  FileAppStore(this._file);

  final File _file;

  @override
  Future<AppBundle?> load() async {
    if (!await _file.exists()) {
      return null;
    }
    final content = await _file.readAsString();
    if (content.trim().isEmpty) {
      return null;
    }
    return AppBundle.fromJson(jsonDecode(content) as Map<String, dynamic>);
  }

  @override
  Future<void> save(AppBundle bundle) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(bundle.toJson()));
  }
}

AppStore createAppStore() {
  final directory = Directory(_resolveAppDirectory());
  final file = File(
    '${directory.path}${Platform.pathSeparator}storm_teleprompter_plus.json',
  );
  return FileAppStore(file);
}

String _resolveAppDirectory() {
  final appData = Platform.environment['APPDATA'];
  if (appData != null && appData.isNotEmpty) {
    return '$appData${Platform.pathSeparator}StormTeleprompterPlus';
  }
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return '$home${Platform.pathSeparator}.storm_teleprompter_plus';
  }
  return Directory.systemTemp.path;
}
