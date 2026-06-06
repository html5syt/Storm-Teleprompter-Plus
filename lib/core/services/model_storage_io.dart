import 'dart:io';

import 'package:archive/archive.dart';

Future<Directory> resolveModelStorageRoot() async {
  final appData = Platform.environment['APPDATA'];
  if (appData != null && appData.isNotEmpty) {
    final root = Directory(
      '$appData${Platform.pathSeparator}StormTeleprompterPlus${Platform.pathSeparator}models',
    );
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    final root = Directory(
      '$home${Platform.pathSeparator}.storm_teleprompter_plus${Platform.pathSeparator}models',
    );
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  final root = Directory.systemTemp.createTempSync(
    'storm_teleprompter_plus_models',
  );
  if (!await root.exists()) {
    await root.create(recursive: true);
  }
  return root;
}

Future<Directory> resolveModelDirectory(String modelId) async {
  final root = await resolveModelStorageRoot();
  final modelDirectory = Directory(
    '${root.path}${Platform.pathSeparator}$modelId',
  );
  if (!await modelDirectory.exists()) {
    await modelDirectory.create(recursive: true);
  }
  return modelDirectory;
}

Future<void> extractDownloadedModel({
  required String archivePath,
  required Directory destinationDirectory,
}) async {
  final archiveFile = File(archivePath);
  if (!await archiveFile.exists()) {
    throw FileSystemException('模型压缩包不存在', archivePath);
  }

  final bytes = await archiveFile.readAsBytes();
  final decoded = _decodeArchive(archivePath, bytes);
  await destinationDirectory.create(recursive: true);

  for (final file in decoded) {
    final normalizedName = _normalizeArchiveEntryName(
      archivePath,
      file.name,
    ).replaceAll('/', Platform.pathSeparator);
    final outputPath =
        '${destinationDirectory.path}${Platform.pathSeparator}$normalizedName';
    if (file.isFile) {
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(file.content as List<int>, flush: true);
    } else {
      await Directory(outputPath).create(recursive: true);
    }
  }
}

String _normalizeArchiveEntryName(String archivePath, String entryName) {
  final rootName = _archiveRootName(archivePath);
  if (entryName == rootName) {
    return '';
  }
  final prefix = '$rootName/';
  if (entryName.startsWith(prefix)) {
    return entryName.substring(prefix.length);
  }
  return entryName;
}

String _archiveRootName(String archivePath) {
  final fileName = archivePath.split(Platform.pathSeparator).last;
  if (fileName.toLowerCase().endsWith('.tar.bz2')) {
    return fileName.substring(0, fileName.length - '.tar.bz2'.length);
  }
  if (fileName.toLowerCase().endsWith('.tar.gz')) {
    return fileName.substring(0, fileName.length - '.tar.gz'.length);
  }
  if (fileName.toLowerCase().endsWith('.tbz2')) {
    return fileName.substring(0, fileName.length - '.tbz2'.length);
  }
  if (fileName.toLowerCase().endsWith('.tgz')) {
    return fileName.substring(0, fileName.length - '.tgz'.length);
  }
  if (fileName.toLowerCase().endsWith('.zip')) {
    return fileName.substring(0, fileName.length - '.zip'.length);
  }
  return fileName;
}

Archive _decodeArchive(String archivePath, List<int> bytes) {
  final lowerPath = archivePath.toLowerCase();
  if (lowerPath.endsWith('.zip')) {
    return ZipDecoder().decodeBytes(bytes);
  }
  if (lowerPath.endsWith('.tar.bz2') || lowerPath.endsWith('.tbz2')) {
    final tarBytes = BZip2Decoder().decodeBytes(bytes);
    return TarDecoder().decodeBytes(tarBytes);
  }
  if (lowerPath.endsWith('.tar.gz') || lowerPath.endsWith('.tgz')) {
    final tarBytes = GZipDecoder().decodeBytes(bytes);
    return TarDecoder().decodeBytes(tarBytes);
  }
  throw UnsupportedError('不支持的模型压缩包格式: $archivePath');
}
