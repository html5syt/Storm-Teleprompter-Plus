import '../models/app_models.dart';

abstract class ModelDownloader {
  Future<DownloadTicket> prepare(
    ModelPackage model, {
    bool preferMirror = true,
  });

  Future<DownloadStatus> download(
    DownloadTicket ticket, {
    void Function(DownloadStatus status)? onProgress,
  });
}

class DownloadTicket {
  const DownloadTicket({
    required this.model,
    required this.sourceUrl,
    required this.localPath,
  });

  final ModelPackage model;
  final String sourceUrl;
  final String localPath;
}

class DownloadStatus {
  const DownloadStatus({
    required this.progress,
    required this.completedBytes,
    required this.totalBytes,
    required this.isFinished,
    this.message,
  });

  final double progress;
  final int completedBytes;
  final int totalBytes;
  final bool isFinished;
  final String? message;
}

String humanBytes(int value) {
  if (value <= 0) {
    return '0 B';
  }
  const units = <String>['B', 'KB', 'MB', 'GB'];
  var current = value.toDouble();
  var unitIndex = 0;
  while (current >= 1024 && unitIndex < units.length - 1) {
    current /= 1024;
    unitIndex += 1;
  }
  return '${current.toStringAsFixed(current >= 10 ? 0 : 1)} ${units[unitIndex]}';
}
