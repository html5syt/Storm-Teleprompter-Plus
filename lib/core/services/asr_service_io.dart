import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../models/app_models.dart';
import 'asr_service_base.dart';
import 'model_storage_io.dart';

class SherpaOnnxAsrService implements TeleprompterAsrService {
  SherpaOnnxAsrService();

  final StreamController<AsrFrame> _frameController =
      StreamController<AsrFrame>.broadcast();
  sherpa_onnx.OnlineRecognizer? _recognizer;
  sherpa_onnx.OnlineStream? _stream;
  ModelPackage? _model;
  bool _ready = false;
  bool _running = false;
  String _statusMessage = '未连接本地识别引擎';

  @override
  Stream<AsrFrame> get frames => _frameController.stream;

  @override
  bool get isReady => _ready;

  @override
  String get statusMessage => _statusMessage;

  @override
  Future<void> initialize({required ModelPackage model}) async {
    if (_ready && _model?.id == model.id) {
      return;
    }

    await stop();
    sherpa_onnx.initBindings();

    final modelDirectory = await resolveModelDirectory(model.id);
    final config = _buildRecognizerConfig(modelDirectory, model);
    _recognizer = sherpa_onnx.OnlineRecognizer(config);
    _stream = _recognizer!.createStream();
    _model = model;
    _ready = true;
    _statusMessage = 'Sherpa 识别引擎已就绪';
  }

  @override
  Future<void> start({required String scriptText}) async {
    if (!_ready || _recognizer == null || _stream == null) {
      throw StateError('识别引擎尚未初始化');
    }

    _running = true;
    _statusMessage = '正在等待音频输入';
  }

  @override
  void acceptWaveform(Float32List samples, int sampleRate) {
    if (!_running || _recognizer == null || _stream == null) {
      return;
    }

    _stream!.acceptWaveform(samples: samples, sampleRate: sampleRate);
    while (_recognizer!.isReady(_stream!)) {
      _recognizer!.decode(_stream!);
      final result = _recognizer!.getResult(_stream!);
      _frameController.add(
        AsrFrame(
          text: result.text,
          isFinal: _recognizer!.isEndpoint(_stream!),
          rms: _calculateRms(samples),
        ),
      );
      if (_recognizer!.isEndpoint(_stream!)) {
        break;
      }
    }
  }

  @override
  Future<void> stop() async {
    _running = false;
    _statusMessage = _ready ? '已停止识别' : '未连接本地识别引擎';
    _stream?.inputFinished();
    if (_recognizer != null) {
      _stream = _recognizer!.createStream();
    }
  }

  double _calculateRms(Float32List samples) {
    if (samples.isEmpty) {
      return 0;
    }

    var sum = 0.0;
    for (final sample in samples) {
      sum += sample * sample;
    }
    return math.sqrt(sum / samples.length);
  }

  sherpa_onnx.OnlineRecognizerConfig _buildRecognizerConfig(
    Directory modelDirectory,
    ModelPackage model,
  ) {
    final layout = _resolveModelLayout(modelDirectory, model);
    final modelConfig = sherpa_onnx.OnlineModelConfig(
      transducer: sherpa_onnx.OnlineTransducerModelConfig(
        encoder: layout.encoder,
        decoder: layout.decoder,
        joiner: layout.joiner,
      ),
      tokens: layout.tokens,
      numThreads: 2,
      provider: 'cpu',
      debug: true,
      modelType: 'zipformer2',
    );

    return sherpa_onnx.OnlineRecognizerConfig(
      feat: const sherpa_onnx.FeatureConfig(sampleRate: 16000, featureDim: 80),
      model: modelConfig,
      ruleFsts: layout.ruleFsts,
      enableEndpoint: true,
      decodingMethod: 'greedy_search',
    );
  }

  _ModelLayout _resolveModelLayout(
    Directory modelDirectory,
    ModelPackage model,
  ) {
    switch (model.id) {
      case 'sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20':
        return _ModelLayout(
          encoder: _requiredFile(
            modelDirectory,
            'encoder-epoch-99-avg-1.int8.onnx',
          ),
          decoder: _requiredFile(modelDirectory, 'decoder-epoch-99-avg-1.onnx'),
          joiner: _requiredFile(modelDirectory, 'joiner-epoch-99-avg-1.onnx'),
          tokens: _requiredFile(modelDirectory, 'tokens.txt'),
          ruleFsts: _optionalFile(modelDirectory, 'itn_zh_number.fst'),
        );
      case 'sherpa-onnx-streaming-zipformer-en-2023-06-26':
        return _ModelLayout(
          encoder: _requiredFile(
            modelDirectory,
            'encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
          ),
          decoder: _requiredFile(
            modelDirectory,
            'decoder-epoch-99-avg-1-chunk-16-left-128.onnx',
          ),
          joiner: _requiredFile(
            modelDirectory,
            'joiner-epoch-99-avg-1-chunk-16-left-128.onnx',
          ),
          tokens: _requiredFile(modelDirectory, 'tokens.txt'),
          ruleFsts: '',
        );
      case 'custom':
        return _ModelLayout(
          encoder: _firstExistingFile(modelDirectory, <String>[
            'encoder.onnx',
            'encoder.int8.onnx',
          ]),
          decoder: _firstExistingFile(modelDirectory, <String>[
            'decoder.onnx',
            'decoder.int8.onnx',
          ]),
          joiner: _firstExistingFile(modelDirectory, <String>[
            'joiner.onnx',
            'joiner.int8.onnx',
          ]),
          tokens: _firstExistingFile(modelDirectory, <String>[
            'tokens.txt',
            'bpe.model',
          ]),
          ruleFsts: _optionalFile(modelDirectory, 'itn_zh_number.fst'),
        );
      default:
        throw UnsupportedError('暂不支持的模型: ${model.id}');
    }
  }

  String _requiredFile(Directory directory, String relativePath) {
    final file = File(
      '${directory.path}${Platform.pathSeparator}$relativePath',
    );
    if (!file.existsSync()) {
      throw FileSystemException('缺少模型文件', file.path);
    }
    return file.path;
  }

  String _optionalFile(Directory directory, String relativePath) {
    final file = File(
      '${directory.path}${Platform.pathSeparator}$relativePath',
    );
    return file.existsSync() ? file.path : '';
  }

  String _firstExistingFile(Directory directory, List<String> relativePaths) {
    for (final relativePath in relativePaths) {
      final file = File(
        '${directory.path}${Platform.pathSeparator}$relativePath',
      );
      if (file.existsSync()) {
        return file.path;
      }
    }
    throw FileSystemException('找不到可用的模型文件', directory.path);
  }
}

class _ModelLayout {
  const _ModelLayout({
    required this.encoder,
    required this.decoder,
    required this.joiner,
    required this.tokens,
    required this.ruleFsts,
  });

  final String encoder;
  final String decoder;
  final String joiner;
  final String tokens;
  final String ruleFsts;
}

TeleprompterAsrService createAsrService() {
  return SherpaOnnxAsrService();
}
