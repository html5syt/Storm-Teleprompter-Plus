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
          'https://hf-mirror.com/csukuangfj/sherpa-onnx-paraformer-zh-2023-09-14/resolve/main/sherpa-onnx-paraformer-zh-2023-09-14.tar.bz2',
      approximateSizeMB: 94,
    ),
    AsrModelInfo(
      id: 'streaming-paraformer',
      name: '流式 Paraformer 中文',
      description: '流式中文语音识别，实时性更好',
      downloadUrl:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-paraformer-bilingual-zh-en.tar.bz2',
      mirrorUrl:
          'https://hf-mirror.com/csukuangfj/sherpa-onnx-streaming-paraformer-bilingual-zh-en/resolve/main/sherpa-onnx-streaming-paraformer-bilingual-zh-en.tar.bz2',
      approximateSizeMB: 82,
    ),
    AsrModelInfo(
      id: 'whisper-tiny',
      name: 'Whisper Tiny',
      description: '轻量级多语言模型，适合性能有限的设备',
      downloadUrl:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-tiny.tar.bz2',
      mirrorUrl: null,
      approximateSizeMB: 75,
    ),
  ];
}

/// ASR 服务下载进度回调
typedef DownloadProgressCallback =
    void Function(double progress, String message);

/// ASR 语音识别服务
///
/// 使用 sherpa-onnx 原生插件替代原始项目的 WASM 实现。
/// 支持动态选择和下载模型，下载支持镜像加速。
class AsrService {
  static AsrService? _instance;

  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  bool _isRunning = false;
  bool _isModelLoaded = false;

  // 回调
  void Function(String text)? onPartial;
  void Function(String text)? onFinal;
  void Function(double rms)? onRms;

  AsrService._();

  /// 获取单例
  static AsrService get instance {
    _instance ??= AsrService._();
    return _instance!;
  }

  /// 模型是否已加载
  bool get isModelLoaded => _isModelLoaded;

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
  /// 支持镜像加速，国内用户可使用 HF Mirror。
  Future<void> downloadModel(
    AsrModelInfo modelInfo, {
    bool useMirror = true,
    DownloadProgressCallback? onProgress,
  }) async {
    final modelDir = await _getModelDir();
    final url = (useMirror && modelInfo.mirrorUrl != null)
        ? modelInfo.mirrorUrl!
        : modelInfo.downloadUrl;

    onProgress?.call(0, '开始下载模型: ${modelInfo.name}');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }

      onProgress?.call(0.5, '下载完成，正在解压...');

      // 解压 tar.bz2
      final archive = BZip2Decoder().decodeBytes(response.bodyBytes);
      // tar 解包
      final tarArchive = TarDecoder().decodeBytes(archive);

      final targetDir = '$modelDir/${modelInfo.id}';
      final dir = Directory(targetDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await dir.create(recursive: true);

      for (final file in tarArchive) {
        final filePath = '$targetDir/${file.name}';
        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filePath).create(recursive: true);
        }
      }

      onProgress?.call(1.0, '模型解压完成');
    } catch (e) {
      onProgress?.call(0, '下载失败: $e');
      rethrow;
    }
  }

  /// 删除已下载的模型
  Future<void> deleteModel(String modelId) async {
    final modelDir = await _getModelDir();
    final dir = Directory('$modelDir/$modelId');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// 加载模型
  ///
  /// 加载指定的 ASR 模型到内存。如果已加载其他模型会先释放。
  Future<void> loadModel(String modelId) async {
    if (_isModelLoaded && _recognizer != null) {
      // 已加载，检查是否是同一个模型
      // 如果需要切换模型，先释放
      unloadModel();
    }

    final modelDir = await _getModelDir();
    final targetDir = '$modelDir/$modelId';

    final dir = Directory(targetDir);
    if (!await dir.exists()) {
      throw Exception('模型未下载: $modelId');
    }

    try {
      // 查找模型文件
      final files = await dir.list(recursive: true).toList();
      String? tokensPath;
      String? encoderPath;
      String? decoderPath;
      String? paraformerPath;

      for (final file in files) {
        if (file is! File) continue;
        final name = file.path.split(Platform.pathSeparator).last;
        if (name == 'tokens.txt') tokensPath = file.path;
        if (name == 'encoder.onnx' || name == 'encoder-epoch-99-avg-1.onnx') {
          encoderPath = file.path;
        }
        if (name == 'decoder.onnx' || name == 'decoder-epoch-99-avg-1.onnx') {
          decoderPath = file.path;
        }
        if (name == 'model.onnx' || name.contains('model.int8.onnx')) {
          paraformerPath = file.path;
        }
      }

      if (tokensPath == null) {
        throw Exception('模型文件不完整：缺少 tokens.txt');
      }

      // 创建识别器配置
      sherpa.OnlineRecognizerConfig config;

      if (paraformerPath != null) {
        // Paraformer 模型
        final modelConfig = sherpa.OnlineModelConfig(
          paraformer: sherpa.OnlineParaformerModelConfig(
            encoder: paraformerPath,
            decoder: paraformerPath,
          ),
          tokens: tokensPath,
          numThreads: 4,
          debug: false,
        );
        config = sherpa.OnlineRecognizerConfig(
          model: modelConfig,
          enableEndpoint: true,
          rule1MinTrailingSilence: 2.4,
          rule2MinTrailingSilence: 1.2,
          rule3MinUtteranceLength: 20,
        );
      } else if (encoderPath != null && decoderPath != null) {
        // Transducer 模型
        final modelConfig = sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: encoderPath,
            decoder: decoderPath,
            joiner: '',
          ),
          tokens: tokensPath,
          numThreads: 4,
          debug: false,
        );
        config = sherpa.OnlineRecognizerConfig(
          model: modelConfig,
          enableEndpoint: true,
          rule1MinTrailingSilence: 2.4,
          rule2MinTrailingSilence: 1.2,
          rule3MinUtteranceLength: 20,
        );
      } else {
        throw Exception('无法识别模型格式：缺少必要的模型文件');
      }

      _recognizer = sherpa.OnlineRecognizer(config);
      _isModelLoaded = true;

      debugPrint('[AsrService] 模型加载成功: $modelId');
    } catch (e) {
      _isModelLoaded = false;
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

    // 检测端点
    if (_recognizer!.isEndpoint(_stream!)) {
      if (result.text.isNotEmpty) {
        onFinal?.call(result.text);
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
    debugPrint('[AsrService] 模型已卸载');
  }

  /// 释放所有资源
  void dispose() {
    unloadModel();
    _instance = null;
  }
}
