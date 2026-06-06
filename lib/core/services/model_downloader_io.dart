import 'dart:io';

import '../models/app_models.dart';
import 'model_downloader.dart';
import 'model_storage_io.dart';

class FileModelDownloader extends ModelDownloader {
  FileModelDownloader(this._baseDir);

  final Directory _baseDir;

  @override
  Future<DownloadTicket> prepare(
    ModelPackage model, {
    bool preferMirror = true,
  }) async {
    final sourceUrl = preferMirror && model.mirrorUrl.isNotEmpty
        ? model.mirrorUrl
        : model.downloadUrl;
    final localPath =
        '${_baseDir.path}${Platform.pathSeparator}${model.id}${Platform.pathSeparator}${model.fileName}';
    return DownloadTicket(
      model: model,
      sourceUrl: sourceUrl,
      localPath: localPath,
    );
  }

  @override
  Future<DownloadStatus> download(
    DownloadTicket ticket, {
    void Function(DownloadStatus status)? onProgress,
  }) async {
    final targetFile = File(ticket.localPath);
    await targetFile.parent.create(recursive: true);

    final request = await HttpClient().getUrl(Uri.parse(ticket.sourceUrl));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        '模型下载失败: ${response.statusCode}',
        uri: Uri.parse(ticket.sourceUrl),
      );
    }

    final total = response.contentLength < 0 ? 0 : response.contentLength;
    var received = 0;
    final sink = targetFile.openWrite();
    await for (final chunk in response) {
      received += chunk.length;
      sink.add(chunk);
      onProgress?.call(
        DownloadStatus(
          progress: total == 0 ? 0 : received / total,
          completedBytes: received,
          totalBytes: total,
          isFinished: false,
          message: '正在下载 ${ticket.model.name}',
        ),
      );
    }
    await sink.flush();
    await sink.close();

    await extractDownloadedModel(
      archivePath: targetFile.path,
      destinationDirectory: Directory(
        '${_baseDir.path}${Platform.pathSeparator}${ticket.model.id}',
      ),
    );

    final finished = DownloadStatus(
      progress: 1,
      completedBytes: received,
      totalBytes: total,
      isFinished: true,
      message: '模型下载完成',
    );
    onProgress?.call(finished);
    return finished;
  }
}
