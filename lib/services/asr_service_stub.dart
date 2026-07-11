import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

class AsrModelInfo {
  final String id;
  final String name;
  final String description;
  final String downloadUrl;
  final String? mirrorUrl;
  final int approximateSizeMB;
  final String languages;
  final String scenario;
  final String accuracy;
  final String latency;
  final int recommendedMemoryMB;

  const AsrModelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.downloadUrl,
    this.mirrorUrl,
    required this.approximateSizeMB,
    this.languages = '中文',
    this.scenario = '通用提词',
    this.accuracy = '标准',
    this.latency = '低',
    this.recommendedMemoryMB = 1024,
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
  bool _isReleased = false;

  AsrService._();

  static AsrService get instance {
    _instance ??= AsrService._();
    return _instance!;
  }

  static void init() {}

  bool get isModelLoaded => false;
  String? get currentModelId => null;
  bool get isRunning => false;

  AsrModelInfo recommendModel() =>
      throw UnsupportedError('ASR is not supported on Web.');

  DownloadProgress getDownloadProgress(String modelId) {
    return const DownloadProgress();
  }

  Map<String, DownloadProgress> get allDownloadProgress => const {};

  Future<void> cancelDownload() async {}

  Future<bool> isModelDownloaded(String modelId) async => false;

  Future<void> downloadModel(
    AsrModelInfo modelInfo, {
    bool useMirror = true,
    String? customMirrorUrl,
    bool useSystemProxy = true,
    DownloadProgressCallback? onProgress,
  }) async {
    throw UnsupportedError('ASR is not supported on Web.');
  }

  Future<void> deleteModel(String modelId) async {}

  Future<String> importModelArchive(
    String archivePath, {
    String? modelId,
  }) async {
    throw UnsupportedError('ASR is not supported on Web.');
  }

  Future<void> loadModel(
    String modelId, {
    int numThreads = 0,
    double rule1MinTrailingSilence = 2.4,
    double rule2MinTrailingSilence = 1.2,
    double rule3MinUtteranceLength = 20.0,
  }) async {
    throw UnsupportedError('ASR is not supported on Web.');
  }

  Future<void> start({
    required void Function(String text) onPartialResult,
    required void Function(String text) onFinalResult,
    void Function(double rms)? onRmsUpdate,
    String? inputDeviceId,
    void Function(Object error)? onError,
  }) async {
    throw UnsupportedError('ASR is not supported on Web.');
  }

  void processAudioSamples(Float32List samples) {}

  double get previewRms => 0;
  String? get previewDeviceId => null;
  String? get previewError => null;
  Future<List<InputDevice>> listInputDevices() async => const [];
  Future<void> startInputPreview(String? deviceId) async {}
  Future<void> stopInputPreview() async {}
  Future<void> openMicrophonePrivacySettings() async {}

  Future<void> stop() async {}

  Future<void> unloadModel() async {}

  Future<void> release() async {
    if (_isReleased) return;
    _isReleased = true;
    _instance = null;
  }

  @override
  void dispose() {
    release();
    super.dispose();
  }
}
