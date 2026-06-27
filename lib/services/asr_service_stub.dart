import 'package:flutter/foundation.dart';

class AsrModelInfo {
  final String id;
  final String name;
  final String description;
  final String downloadUrl;
  final String? mirrorUrl;
  final int approximateSizeMB;

  const AsrModelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.downloadUrl,
    this.mirrorUrl,
    required this.approximateSizeMB,
  });
}

class AsrModels {
  AsrModels._();

  static const List<AsrModelInfo> availableModels = [];
}

typedef DownloadProgressCallback =
    void Function(double progress, String message);

class DownloadProgress {
  final double progress;
  final String message;
  final bool isDownloading;
  final bool isCompleted;
  final String? error;

  const DownloadProgress({
    this.progress = 0,
    this.message = '',
    this.isDownloading = false,
    this.isCompleted = false,
    this.error,
  });

  DownloadProgress copyWith({
    double? progress,
    String? message,
    bool? isDownloading,
    bool? isCompleted,
    String? error,
  }) {
    return DownloadProgress(
      progress: progress ?? this.progress,
      message: message ?? this.message,
      isDownloading: isDownloading ?? this.isDownloading,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error ?? this.error,
    );
  }
}

class AsrService with ChangeNotifier {
  static AsrService? _instance;

  AsrService._();

  static AsrService get instance {
    _instance ??= AsrService._();
    return _instance!;
  }

  static void init() {}

  bool get isModelLoaded => false;
  String? get currentModelId => null;
  bool get isRunning => false;

  DownloadProgress getDownloadProgress(String modelId) {
    return const DownloadProgress();
  }

  Map<String, DownloadProgress> get allDownloadProgress => const {};

  void cancelDownload() {}

  Future<bool> isModelDownloaded(String modelId) async => false;

  Future<void> downloadModel(
    AsrModelInfo modelInfo, {
    bool useMirror = true,
    String? customMirrorUrl,
    DownloadProgressCallback? onProgress,
  }) async {
    throw UnsupportedError('ASR is not supported on Web.');
  }

  Future<void> deleteModel(String modelId) async {}

  Future<void> loadModel(String modelId) async {
    throw UnsupportedError('ASR is not supported on Web.');
  }

  Future<void> start({
    required void Function(String text) onPartialResult,
    required void Function(String text) onFinalResult,
    void Function(double rms)? onRmsUpdate,
  }) async {
    throw UnsupportedError('ASR is not supported on Web.');
  }

  void processAudioSamples(Float32List samples) {}

  Future<void> stop() async {}

  void unloadModel() {}

  @override
  void dispose() {
    _instance = null;
    super.dispose();
  }
}
