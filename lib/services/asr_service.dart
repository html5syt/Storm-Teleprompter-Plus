import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// ASR 模型信息
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

/// 可用的 ASR 模型列表
class AsrModels {
  AsrModels._();

  static const List<AsrModelInfo> availableModels = [
    AsrModelInfo(
      id: 'paraformer-zh',
      name: 'Paraformer 中文',
      description: '中文语音识别模型，适合大多数中文场景',
      downloadUrl:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-paraformer-zh-2023-09-14.tar.bz2',
      mirrorUrl:
          'https://hf-mirror.com/k2-fsa/sherpa-onnx/resolve/main/sherpa-onnx-paraformer-zh-2023-09-14.tar.bz2',
      approximateSizeMB: 234,
    ),
    AsrModelInfo(
      id: 'streaming-paraformer',
      name: '流式 Paraformer 中文',
      description: '流式中文语音识别，实时性更好',
      downloadUrl:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-paraformer-bilingual-zh-en.tar.bz2',
      mirrorUrl:
          'https://hf-mirror.com/k2-fsa/sherpa-onnx/resolve/main/sherpa-onnx-streaming-paraformer-bilingual-zh-en.tar.bz2',
      approximateSizeMB: 1047,
    ),
    AsrModelInfo(
      id: 'zipformer2-ced',
      name: 'Zipformer2 CED 中文',
      description: '流式中文语音识别，Transducer 架构',
      downloadUrl:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23.tar.bz2',
      mirrorUrl: null,
      approximateSizeMB: 74,
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
  bool _isRunning = false;
  bool _isModelLoaded = false;
  String? _currentModelId;

  // 回调
  void Function(String text)? onPartial;
  void Function(String text)? onFinal;
  void Function(double rms)? onRms;

  // ─── 下载状态跟踪 ──────────────────────────────────────
  final Map<String, DownloadProgress> _downloadProgress = {};
  StreamSubscription? _currentDownloadSubscription;
  String? _currentDownloadModelId;
  bool _currentDownloadCancelled = false;

  /// 获取指定模型的下载进度
  DownloadProgress getDownloadProgress(String modelId) {
    return _downloadProgress[modelId] ?? const DownloadProgress();
  }

  /// 所有模型的下载进度（只读视图）
  Map<String, DownloadProgress> get allDownloadProgress =>
      Map.unmodifiable(_downloadProgress);

  /// 取消当前正在进行的下载
  void cancelDownload() {
    if (_currentDownloadSubscription != null &&
        _currentDownloadModelId != null) {
      _currentDownloadCancelled = true;
      _currentDownloadSubscription!.cancel();
      _currentDownloadSubscription = null;
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
    return targetDir.exists();
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
    DownloadProgressCallback? onProgress,
  }) async {
    final modelId = modelInfo.id;
    // 如果已经在下载，不重复启动
    if (_downloadProgress[modelId]?.isDownloading == true) return;

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
      final sourceLabel =
          attempt == 0 && useMirror && modelInfo.mirrorUrl != null
          ? '镜像'
          : '原始';

      updateProgress(0, '[$sourceLabel] 开始下载: ${modelInfo.name}');

      // 临时下载文件路径
      final tempPath = '$modelDir/${modelInfo.id}.tar.bz2';
      final tempFile = File(tempPath);

      try {
        // ── 流式下载：分块写入磁盘 ──
        final request = http.Request('GET', Uri.parse(url));
        final response = await http.Client().send(request);

        if (response.statusCode != 200) {
          lastError = 'HTTP ${response.statusCode}';
          updateProgress(0, '[$sourceLabel] 下载失败: $lastError，尝试其他地址...');
          continue;
        }

        final contentLength = response.contentLength ?? 0;
        int downloaded = 0;
        final sink = tempFile.openWrite();

        _currentDownloadSubscription = response.stream.listen(
          (chunk) {
            sink.add(chunk);
            downloaded += chunk.length;
            if (contentLength > 0) {
              final progress = downloaded / contentLength;
              final mb = (downloaded / (1024 * 1024)).toStringAsFixed(1);
              final totalMb = (contentLength / (1024 * 1024))
                  .toStringAsFixed(1);
              updateProgress(
                progress * 0.8,
                '[$sourceLabel] 下载中: ${mb}MB / ${totalMb}MB (${(progress * 100).toStringAsFixed(0)}%)',
              );
            }
          },
          onDone: () async {
            await sink.close();
          },
          onError: (e) async {
            await sink.close();
            throw e;
          },
          cancelOnError: false,
        );

        await _currentDownloadSubscription!.asFuture<void>();

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

        // ── 读取临时文件并解压 ──
        final bytes = await tempFile.readAsBytes();

        // 解压 tar.bz2
        final bz2Decoded = BZip2Decoder().decodeBytes(bytes);
        final tarArchive = TarDecoder().decodeBytes(bz2Decoded);

        final targetDir = '$modelDir/${modelInfo.id}';
        final dir = Directory(targetDir);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
        await dir.create(recursive: true);

        final totalFiles = tarArchive.length;
        for (int i = 0; i < totalFiles; i++) {
          final file = tarArchive[i];
          final filePath = '$targetDir/${file.name}';
          if (file.isFile) {
            final outFile = File(filePath);
            await outFile.parent.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          } else {
            await Directory(filePath).create(recursive: true);
          }
          final extractProgress = (i + 1) / totalFiles;
          updateProgress(
            0.8 + extractProgress * 0.2,
            '解压中: ${i + 1}/$totalFiles 文件',
          );
        }

        // 清理临时文件
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        completeProgress();
        return; // 成功
      } catch (e) {
        lastError = e.toString();
        updateProgress(0, '[$sourceLabel] 出错: $lastError，尝试其他地址...');
        // 清理临时文件
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
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

  /// 加载模型
  ///
  /// 加载指定的 ASR 模型到内存。如果已加载其他模型会先释放。
  ///
  /// 必须在调用前确保 [init] 已执行。
  /// 支持的模型格式：
  /// - 流式 Transducer (Zipformer): encoder/decoder/joiner + tokens
  /// - 流式 Paraformer: encoder/decoder + tokens
  Future<void> loadModel(String modelId) async {
    if (!_bindingsInitialized) {
      throw StateError('sherpa-onnx 尚未初始化，请先调用 AsrService.init()');
    }

    if (_isModelLoaded) {
      unloadModel();
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

      if (joinerPath != null) {
        // Transducer 模型（如 Zipformer）
        modelConfig = sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: encoderPath,
            decoder: decoderPath,
            joiner: joinerPath,
          ),
          tokens: tokensPath,
          numThreads: 4,
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
          numThreads: 4,
          debug: kDebugMode,
        );
        debugPrint('[AsrService] 加载流式 Paraformer 模型');
      }

      final config = sherpa.OnlineRecognizerConfig(
        model: modelConfig,
        enableEndpoint: true,
        rule1MinTrailingSilence: 2.4,
        rule2MinTrailingSilence: 1.2,
        rule3MinUtteranceLength: 20,
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
      _isRunning = true;

      // 使用 record 插件进行音频采集
      // 注意：实际音频采集需要在使用时通过 record 包实现
      // 这里提供接口，具体采集逻辑在 UI 层通过回调实现
      debugPrint('[AsrService] ASR 识别已启动');
    } catch (e) {
      _isRunning = false;
      debugPrint('[AsrService] ASR 启动失败: $e');
      rethrow;
    }
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

    _stream?.free();
    _stream = null;

    debugPrint('[AsrService] ASR 识别已停止');
  }

  /// 卸载模型，释放资源
  void unloadModel() {
    stop();
    _recognizer?.free();
    _recognizer = null;
    _isModelLoaded = false;
    _currentModelId = null;
    debugPrint('[AsrService] 模型已卸载');
  }

  /// 释放所有资源
  @override
  void dispose() {
    unloadModel();
    _instance = null;
    super.dispose();
  }
}
