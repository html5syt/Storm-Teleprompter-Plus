import '../models/app_models.dart';
import 'model_downloader.dart';

class UnsupportedWebModelDownloader extends ModelDownloader {
  @override
  Future<DownloadTicket> prepare(
    ModelPackage model, {
    bool preferMirror = true,
  }) async {
    final source = preferMirror && model.mirrorUrl.isNotEmpty
        ? model.mirrorUrl
        : model.downloadUrl;
    return DownloadTicket(model: model, sourceUrl: source, localPath: '');
  }

  @override
  Future<DownloadStatus> download(
    DownloadTicket ticket, {
    void Function(DownloadStatus status)? onProgress,
  }) async {
    throw UnsupportedError('Web 端不支持直接写入本地模型目录，请使用桌面或移动端下载模型。');
  }
}
