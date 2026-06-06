import 'dart:io';

import 'model_downloader.dart';
import 'model_downloader_io.dart';

ModelDownloader createModelDownloader() {
  final appData = Platform.environment['APPDATA'];
  if (appData != null && appData.isNotEmpty) {
    return FileModelDownloader(
      Directory(
        '$appData${Platform.pathSeparator}StormTeleprompterPlus${Platform.pathSeparator}models',
      ),
    );
  }
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return FileModelDownloader(
      Directory(
        '$home${Platform.pathSeparator}.storm_teleprompter_plus${Platform.pathSeparator}models',
      ),
    );
  }
  return FileModelDownloader(
    Directory.systemTemp.createTempSync('storm_teleprompter_plus_models'),
  );
}
