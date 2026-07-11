import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:archive/archive_io.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// ASR 模型信息
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

/// 可用的 ASR 模型列表
class AsrModels {
  AsrModels._();

  static const List<AsrModelInfo> availableModels = [
    AsrModelInfo(
      id: 'zipformer-bilingual-zh-en',
      name: 'Zipformer 中英双语',
      description: '官方流式中英双语 Transducer 模型，兼顾准确率与实时性',
      downloadUrl:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20.tar.bz2',
      mirrorUrl: null,
      approximateSizeMB: 322,
      languages: '中文、英文',
      scenario: '中英混合稿件与高准确率场景',
      accuracy: '很高',
      latency: '中',
      recommendedMemoryMB: 3072,
    ),
    AsrModelInfo(
      id: 'zipformer2-ced',
      name: 'Zipformer2 CED 中文',
      description: '流式中文语音识别，Transducer 架构',
      downloadUrl:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23.tar.bz2',
      mirrorUrl: null,
      approximateSizeMB: 74,
      scenario: '资源受限设备和低延迟跟随',
      accuracy: '标准',
      latency: '很低',
      recommendedMemoryMB: 768,
    ),
  ];
}

/// ASR 服务下载进度回调
typedef DownloadProgressCallback =
    void Function(double progress, String message);

/// 单个模型的下载状态
class DownloadProgress {
  final double progress; // 0.0 ~ 1.0
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

/// ASR 语音识别服务
///
/// 使用 sherpa-onnx 原生插件替代原始项目的 WASM 实现。
/// 支持动态选择和下载模型，下载支持镜像加速。
///
/// 使用前必须先调用 [init] 完成 sherpa-onnx 原生绑定初始化。
class AsrService with ChangeNotifier {
  static AsrService? _instance;
  static bool _bindingsInitialized = false;

  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioRecorder _previewRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<Uint8List>? _previewSubscription;
  bool _isRunning = false;
  bool _isModelLoaded = false;
  bool _isReleased = false;
  String? _currentModelId;

  // 回调
  void Function(String text)? onPartial;
  void Function(String text)? onFinal;
  void Function(double rms)? onRms;

  // ─── 下载状态跟踪 ──────────────────────────────────────
  final Map<String, DownloadProgress> _downloadProgress = {};
  StreamSubscription? _currentDownloadSubscription;
  Completer<void>? _currentDownloadCompleter;
  String? _currentDownloadModelId;
  bool _currentDownloadCancelled = false;
  http.Client? _currentDownloadClient;
  double _previewRms = 0;
  String? _previewDeviceId;

  /// 获取指定模型的下载进度
  DownloadProgress getDownloadProgress(String modelId) {
    return _downloadProgress[modelId] ?? const DownloadProgress();
  }

  /// 所有模型的下载进度（只读视图）
  Map<String, DownloadProgress> get allDownloadProgress =>
      Map.unmodifiable(_downloadProgress);

  /// 取消当前正在进行的下载
  Future<void> cancelDownload() async {
    if (_currentDownloadModelId != null) {
      _currentDownloadCancelled = true;
      final subscription = _currentDownloadSubscription;
      _currentDownloadSubscription = null;
      await subscription?.cancel();
      _currentDownloadClient?.close();
      _currentDownloadClient = null;
      if (_currentDownloadCompleter?.isCompleted == false) {
        _currentDownloadCompleter!.complete();
      }
      final modelId = _currentDownloadModelId!;
      _currentDownloadModelId = null;
      _downloadProgress[modelId] = const DownloadProgress(
        isDownloading: false,
        message: '下载已取消',
      );
      notifyListeners();
    }
  }

  AsrService._();

  /// 获取单例
  static AsrService get instance {
    _instance ??= AsrService._();
    return _instance!;
  }

  /// 初始化 sherpa-onnx 原生绑定（只需调用一次）
  ///
  /// 必须在创建任何 OnlineRecognizer 之前调用。
  /// Flutter 平台由原生插件自动提供库路径，无需手动指定。
  static void init() {
    if (!_bindingsInitialized) {
      sherpa.initBindings();
      _bindingsInitialized = true;
      debugPrint('[AsrService] sherpa-onnx 原生绑定已初始化');
    }
  }

  /// 模型是否已加载
  bool get isModelLoaded => _isModelLoaded;

  /// 当前加载的模型 ID
  String? get currentModelId => _currentModelId;

  /// 是否正在运行
  bool get isRunning => _isRunning;
  double get previewRms => _previewRms;
  String? get previewDeviceId => _previewDeviceId;

  Future<List<InputDevice>> listInputDevices() async {
    if (!await _previewRecorder.hasPermission()) return const [];
    return _previewRecorder.listInputDevices();
  }

  Future<void> startInputPreview(String? deviceId) async {
    await stopInputPreview();
    if (!await _previewRecorder.hasPermission()) {
      throw StateError('没有麦克风权限');
    }
    final devices = await _previewRecorder.listInputDevices();
    InputDevice? device;
    if (deviceId != null && deviceId.isNotEmpty) {
      for (final candidate in devices) {
        if (candidate.id == deviceId) {
          device = candidate;
          break;
        }
      }
      if (device == null) throw StateError('选择的麦克风设备当前不可用');
    }
    _previewDeviceId = device?.id ?? '';
    final stream = await _previewRecorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        device: device,
      ),
    );
    _previewSubscription = stream.listen((bytes) {
      _previewRms = _calculatePcm16Rms(bytes);
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> stopInputPreview() async {
    await _previewSubscription?.cancel();
    _previewSubscription = null;
    try {
      await _previewRecorder.stop();
    } catch (_) {}
    _previewRms = 0;
    _previewDeviceId = null;
    notifyListeners();
  }

  AsrModelInfo recommendModel() {
    final processors = Platform.numberOfProcessors;
    final preferredId = processors >= 8
        ? 'zipformer-bilingual-zh-en'
        : 'zipformer2-ced';
    return AsrModels.availableModels.firstWhere(
      (model) => model.id == preferredId,
    );
  }

  /// 获取模型存储目录
  Future<String> _getModelDir() async {
    final appDir = await getApplicationSupportDirectory();
    final modelDir = Directory('${appDir.path}/asr_models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir.path;
  }

  /// 检查模型是否已下载
  Future<bool> isModelDownloaded(String modelId) async {
    final modelDir = await _getModelDir();
    final targetDir = Directory('$modelDir/$modelId');
    return await targetDir.exists() &&
        await _containsRequiredModelFiles(targetDir);
  }

  /// 下载并解压 ASR 模型
  ///
  /// 支持镜像加速，国内用户可使用 HF Mirror 或 GitHub 代理。
  /// 使用流式下载，将文件分块写入磁盘，避免大模型撑爆内存。
  /// 自动重试：镜像失败后回退到原始地址。
  Future<void> downloadModel(
    AsrModelInfo modelInfo, {
    bool useMirror = true,
    String? customMirrorUrl, // 自定义镜像 URL，eg. https://gh-proxy.com/
    bool useSystemProxy = true,
    DownloadProgressCallback? onProgress,
  }) async {
    final modelId = modelInfo.id;
    // 如果已经在下载，不重复启动
    if (_currentDownloadModelId != null ||
        _downloadProgress[modelId]?.isDownloading == true) {
      return;
    }

    _currentDownloadCancelled = false;
    _currentDownloadModelId = modelId;
    _downloadProgress[modelId] = DownloadProgress(
      isDownloading: true,
      message: '准备下载...',
    );
    notifyListeners();

    void updateProgress(double p, String msg) {
      _downloadProgress[modelId] = DownloadProgress(
        isDownloading: true,
        progress: p,
        message: msg,
      );
      notifyListeners();
      onProgress?.call(p, msg);
    }

    void completeProgress() {
      _downloadProgress[modelId] = const DownloadProgress(
        isCompleted: true,
        progress: 1.0,
        message: '下载完成',
      );
      _currentDownloadModelId = null;
      notifyListeners();
    }

    void failProgress(String error) {
      _downloadProgress[modelId] = DownloadProgress(
        isDownloading: false,
        isCompleted: false,
        progress: 0,
        error: error,
        message: '下载失败: $error',
      );
      _currentDownloadModelId = null;
      notifyListeners();
    }

    final modelDir = await _getModelDir();
    final urls = <String>[];

    // 优先使用自定义镜像 URL（包装原始下载地址）
    if (useMirror && customMirrorUrl != null && customMirrorUrl.isNotEmpty) {
      // GitHub 镜像格式：镜像URL + 原始下载URL
      urls.add(
        '${customMirrorUrl.endsWith('/') ? customMirrorUrl : '$customMirrorUrl/'}${modelInfo.downloadUrl}',
      );
    } else if (useMirror && modelInfo.mirrorUrl != null) {
      urls.add(modelInfo.mirrorUrl!);
    }
    urls.add(modelInfo.downloadUrl);

    // 依次尝试每个 URL
    var lastError = '';
    for (int attempt = 0; attempt < urls.length; attempt++) {
      if (_currentDownloadCancelled) {
        _currentDownloadModelId = null;
        return;
      }

      final url = urls[attempt];
      final sourceLabel = url == modelInfo.downloadUrl ? '原始' : '镜像';

      updateProgress(0, '[$sourceLabel] 开始下载: ${modelInfo.name}');

      // 临时下载文件路径
      final tempPath = '$modelDir/${modelInfo.id}.tar.bz2';
      final tempFile = File(tempPath);

      try {
        // ── 流式下载：分块写入磁盘 ──
        final request = http.Request('GET', Uri.parse(url));
        final client = useSystemProxy
            ? IOClient(
                HttpClient()..findProxy = HttpClient.findProxyFromEnvironment,
              )
            : http.Client();
        _currentDownloadClient = client;
        final response = await client.send(request);

        if (response.statusCode != 200) {
          client.close();
          if (identical(_currentDownloadClient, client)) {
            _currentDownloadClient = null;
          }
          lastError = 'HTTP ${response.statusCode}';
          updateProgress(0, '[$sourceLabel] 下载失败: $lastError，尝试其他地址...');
          continue;
        }

        final contentLength = response.contentLength ?? 0;
        int downloaded = 0;
        final sink = tempFile.openWrite();

        final downloadCompleter = Completer<void>();
        _currentDownloadCompleter = downloadCompleter;
        _currentDownloadSubscription = response.stream.listen(
          (chunk) {
            sink.add(chunk);
            downloaded += chunk.length;
            if (contentLength > 0) {
              final progress = downloaded / contentLength;
              final mb = (downloaded / (1024 * 1024)).toStringAsFixed(1);
              final totalMb = (contentLength / (1024 * 1024)).toStringAsFixed(
                1,
              );
              updateProgress(
                progress * 0.8,
                '[$sourceLabel] 下载中: ${mb}MB / ${totalMb}MB (${(progress * 100).toStringAsFixed(0)}%)',
              );
            }
          },
          onDone: () async {
            await sink.close();
            if (!downloadCompleter.isCompleted) downloadCompleter.complete();
          },
          onError: (e) async {
            await sink.close();
            if (!downloadCompleter.isCompleted) {
              downloadCompleter.completeError(e);
            }
          },
          cancelOnError: false,
        );

        await downloadCompleter.future;
        _currentDownloadCompleter = null;
        _currentDownloadSubscription = null;
        client.close();
        if (identical(_currentDownloadClient, client)) {
          _currentDownloadClient = null;
        }

        if (_currentDownloadCancelled) {
          await sink.close();
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          _currentDownloadModelId = null;
          _currentDownloadSubscription = null;
          return;
        }

        updateProgress(0.8, '下载完成，正在解压...');

        final targetDir = '$modelDir/${modelInfo.id}';
        final dir = Directory(targetDir);
        final stagingDir = Directory('$targetDir.importing');
        if (await stagingDir.exists()) await stagingDir.delete(recursive: true);
        await stagingDir.create(recursive: true);

        var extractedFiles = 0;
        await extractFileToDisk(
          tempPath,
          stagingDir.path,
          callback: (entry) {
            if (_currentDownloadCancelled) {
              throw StateError('模型下载已取消');
            }
            extractedFiles++;
            updateProgress(0.9, '解压中: $extractedFiles 个文件');
          },
        );
        if (!await _containsRequiredModelFiles(stagingDir)) {
          await stagingDir.delete(recursive: true);
          throw const FormatException('下载的模型缺少 tokens、encoder 或 decoder 文件');
        }
        if (_currentDownloadCancelled) {
          await stagingDir.delete(recursive: true);
          if (await tempFile.exists()) await tempFile.delete();
          return;
        }
        if (await dir.exists()) await dir.delete(recursive: true);
        await stagingDir.rename(targetDir);

        // 清理临时文件
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        completeProgress();
        return; // 成功
      } catch (e) {
        _currentDownloadClient?.close();
        _currentDownloadClient = null;
        _currentDownloadCompleter = null;
        _currentDownloadSubscription = null;
        lastError = e.toString();
        updateProgress(0, '[$sourceLabel] 出错: $lastError，尝试其他地址...');
        // 清理临时文件
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        final stagingDir = Directory('$modelDir/${modelInfo.id}.importing');
        if (await stagingDir.exists()) {
          await stagingDir.delete(recursive: true);
        }
        if (_currentDownloadCancelled) return;
      }
    }

    // 所有地址都失败
    failProgress(lastError);
    throw Exception('所有下载地址均失败: $lastError');
  }

  /// 删除已下载的模型
  Future<void> deleteModel(String modelId) async {
    final modelDir = await _getModelDir();
    final dir = Directory('$modelDir/$modelId');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    _downloadProgress.remove(modelId);
    notifyListeners();
  }

  /// Imports a downloaded Sherpa-Onnx .zip or .tar.bz2 model archive.
  Future<String> importModelArchive(
    String archivePath, {
    String? modelId,
  }) async {
    final source = File(archivePath);
    if (!await source.exists()) throw ArgumentError('模型文件不存在');
    final lower = archivePath.toLowerCase();
    final resolvedId = (modelId == null || modelId.trim().isEmpty)
        ? source.uri.pathSegments.last
              .replaceFirst(RegExp(r'\.tar\.bz2$', caseSensitive: false), '')
              .replaceFirst(RegExp(r'\.zip$', caseSensitive: false), '')
              .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-')
        : modelId.trim();
    if (resolvedId.isEmpty) throw ArgumentError('无法确定模型 ID');

    if (!lower.endsWith('.zip') &&
        !lower.endsWith('.tar.bz2') &&
        !lower.endsWith('.tbz')) {
      throw const FormatException('仅支持 .zip、.tar.bz2 和 .tbz 模型包');
    }

    final modelRoot = await _getModelDir();
    final target = Directory('$modelRoot/$resolvedId');
    final staging = Directory('${target.path}.importing');
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    try {
      await extractFileToDisk(archivePath, staging.path);
      if (!await _containsRequiredModelFiles(staging)) {
        throw const FormatException('模型包缺少 tokens、encoder 或 decoder 文件');
      }
      if (await target.exists()) await target.delete(recursive: true);
      await staging.rename(target.path);
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
    _downloadProgress[resolvedId] = const DownloadProgress(
      progress: 1,
      isCompleted: true,
      message: '本地导入完成',
    );
    notifyListeners();
    return resolvedId;
  }

  Future<bool> _containsRequiredModelFiles(Directory directory) async {
    var hasTokens = false;
    var hasEncoder = false;
    var hasDecoder = false;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last.toLowerCase();
      hasTokens |= name == 'tokens.txt';
      hasEncoder |= name.contains('encoder') && name.endsWith('.onnx');
      hasDecoder |= name.contains('decoder') && name.endsWith('.onnx');
    }
    return hasTokens && hasEncoder && hasDecoder;
  }

  /// 加载模型
  ///
  /// 加载指定的 ASR 模型到内存。如果已加载其他模型会先释放。
  ///
  /// 必须在调用前确保 [init] 已执行。
  /// 支持的模型格式：
  /// - 流式 Transducer (Zipformer): encoder/decoder/joiner + tokens
  /// - 流式 Paraformer: encoder/decoder + tokens
  Future<void> loadModel(
    String modelId, {
    int numThreads = 0,
    double rule1MinTrailingSilence = 2.4,
    double rule2MinTrailingSilence = 1.2,
    double rule3MinUtteranceLength = 20.0,
  }) async {
    if (!_bindingsInitialized) {
      throw StateError('sherpa-onnx 尚未初始化，请先调用 AsrService.init()');
    }

    if (_isModelLoaded) {
      await unloadModel();
    }

    final modelDir = await _getModelDir();
    final targetDir = '$modelDir/$modelId';

    final dir = Directory(targetDir);
    if (!await dir.exists()) {
      throw Exception('模型未下载: $modelId');
    }

    try {
      // 查找模型文件 —— 按文件名关键词匹配
      final files = await dir.list(recursive: true).toList();
      String? tokensPath;
      String? encoderPath;
      String? decoderPath;
      String? joinerPath;

      for (final file in files) {
        if (file is! File) continue;
        final name = file.path.split(Platform.pathSeparator).last;
        final lower = name.toLowerCase();

        if (lower == 'tokens.txt') {
          tokensPath = file.path;
        } else if (lower.contains('encoder') && lower.endsWith('.onnx')) {
          encoderPath = file.path;
        } else if (lower.contains('decoder') && lower.endsWith('.onnx')) {
          decoderPath = file.path;
        } else if (lower.contains('joiner') && lower.endsWith('.onnx')) {
          joinerPath = file.path;
        }
      }

      if (tokensPath == null) {
        throw Exception('模型文件不完整：缺少 tokens.txt');
      }

      // 根据实际存在的文件推断模型类型
      // 流式 Transducer: 有 encoder + decoder + joiner
      // 流式 Paraformer: 有 encoder + decoder，无 joiner
      if (encoderPath == null || decoderPath == null) {
        throw Exception(
          '模型文件不完整：缺少 encoder.onnx 或 decoder.onnx。'
          '该模型可能不是流式模型（离线模型如 Whisper 不支持 OnlineRecognizer）。',
        );
      }

      // 构建识别器配置
      sherpa.OnlineModelConfig modelConfig;
      final resolvedThreads = numThreads > 0
          ? numThreads
          : max(1, min(8, Platform.numberOfProcessors ~/ 2));

      if (joinerPath != null) {
        // Transducer 模型（如 Zipformer）
        modelConfig = sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: encoderPath,
            decoder: decoderPath,
            joiner: joinerPath,
          ),
          tokens: tokensPath,
          numThreads: resolvedThreads,
          debug: kDebugMode,
        );
        debugPrint('[AsrService] 加载 Transducer 模型');
      } else {
        // 流式 Paraformer 模型
        modelConfig = sherpa.OnlineModelConfig(
          paraformer: sherpa.OnlineParaformerModelConfig(
            encoder: encoderPath,
            decoder: decoderPath,
          ),
          tokens: tokensPath,
          numThreads: resolvedThreads,
          debug: kDebugMode,
        );
        debugPrint('[AsrService] 加载流式 Paraformer 模型');
      }

      final config = sherpa.OnlineRecognizerConfig(
        model: modelConfig,
        enableEndpoint: true,
        rule1MinTrailingSilence: rule1MinTrailingSilence,
        rule2MinTrailingSilence: rule2MinTrailingSilence,
        rule3MinUtteranceLength: rule3MinUtteranceLength,
      );

      _recognizer = sherpa.OnlineRecognizer(config);
      _isModelLoaded = true;
      _currentModelId = modelId;

      debugPrint('[AsrService] 模型加载成功: $modelId');
    } catch (e) {
      _isModelLoaded = false;
      _currentModelId = null;
      debugPrint('[AsrService] 模型加载失败: $e');
      rethrow;
    }
  }

  /// 开始语音识别
  ///
  /// 启动麦克风采集并开始实时识别。
  Future<void> start({
    required void Function(String text) onPartialResult,
    required void Function(String text) onFinalResult,
    void Function(double rms)? onRmsUpdate,
    String? inputDeviceId,
  }) async {
    if (_isRunning) return;
    if (!_isModelLoaded || _recognizer == null) {
      throw Exception('ASR 模型未加载');
    }

    onPartial = onPartialResult;
    onFinal = onFinalResult;
    onRms = onRmsUpdate;

    try {
      _stream = _recognizer!.createStream();
      if (!await _recorder.hasPermission()) {
        throw StateError('没有麦克风权限，无法启动语音识别');
      }
      if (!await _recorder.isEncoderSupported(AudioEncoder.pcm16bits)) {
        throw UnsupportedError('当前平台不支持 PCM16 麦克风流');
      }
      InputDevice? inputDevice;
      if (inputDeviceId != null && inputDeviceId.isNotEmpty) {
        final devices = await _recorder.listInputDevices();
        for (final candidate in devices) {
          if (candidate.id == inputDeviceId) {
            inputDevice = candidate;
            break;
          }
        }
        if (inputDevice == null) {
          throw StateError('选择的麦克风设备当前不可用');
        }
      }

      final audioStream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
          device: inputDevice,
        ),
      );
      _isRunning = true;
      _audioSubscription = audioStream.listen(
        _processPcm16Chunk,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('[AsrService] 麦克风音频流错误: $error');
          unawaited(stop());
        },
      );

      debugPrint('[AsrService] ASR 识别已启动');
    } catch (e) {
      _isRunning = false;
      _stream?.free();
      _stream = null;
      debugPrint('[AsrService] ASR 启动失败: $e');
      rethrow;
    }
  }

  void _processPcm16Chunk(Uint8List bytes) {
    if (bytes.length < 2) return;
    final sampleCount = bytes.length ~/ 2;
    final samples = Float32List(sampleCount);
    final data = ByteData.sublistView(bytes, 0, sampleCount * 2);
    for (var i = 0; i < sampleCount; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    processAudioSamples(samples);
  }

  double _calculatePcm16Rms(Uint8List bytes) {
    if (bytes.length < 2) return 0;
    final sampleCount = bytes.length ~/ 2;
    final data = ByteData.sublistView(bytes, 0, sampleCount * 2);
    var sumSquares = 0.0;
    for (var i = 0; i < sampleCount; i++) {
      final sample = data.getInt16(i * 2, Endian.little) / 32768.0;
      sumSquares += sample * sample;
    }
    return sqrt(sumSquares / sampleCount);
  }

  /// 处理音频数据
  ///
  /// 将 PCM 音频数据送入识别器进行处理。
  /// [samples] 16kHz 采样率的 Float32 音频数据
  void processAudioSamples(Float32List samples) {
    if (!_isRunning || _recognizer == null || _stream == null) return;

    // 计算 RMS 音量
    double sumSquares = 0;
    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      sumSquares += s * s;
    }
    final rms = sqrt(sumSquares / samples.length);
    onRms?.call(rms);

    // 送入识别器
    _stream!.acceptWaveform(samples: samples, sampleRate: 16000);

    // 持续解码
    while (_recognizer!.isReady(_stream!)) {
      _recognizer!.decode(_stream!);
    }

    // 获取中间结果
    final result = _recognizer!.getResult(_stream!);
    if (result.text.isNotEmpty) {
      onPartial?.call(result.text);
    }

    // 端点检测 —— 说话停顿后触发 onFinal 回调
    if (_recognizer!.isEndpoint(_stream!)) {
      final text = result.text.trim();
      if (text.isNotEmpty) {
        onFinal?.call(text);
      }
      _recognizer!.reset(_stream!);
    }
  }

  /// 停止语音识别
  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;

    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _recorder.stop();

    _stream?.free();
    _stream = null;

    debugPrint('[AsrService] ASR 识别已停止');
  }

  /// 卸载模型，释放资源
  Future<void> unloadModel() async {
    await stop();
    _recognizer?.free();
    _recognizer = null;
    _isModelLoaded = false;
    _currentModelId = null;
    debugPrint('[AsrService] 模型已卸载');
  }

  /// Final application shutdown. The service cannot be reused afterwards.
  Future<void> release() async {
    if (_isReleased) return;
    _isReleased = true;
    await unloadModel();
    await stopInputPreview();
    await _recorder.dispose();
    await _previewRecorder.dispose();
    _instance = null;
  }

  /// 释放所有资源
  @override
  void dispose() {
    unawaited(release());
    super.dispose();
  }
}
