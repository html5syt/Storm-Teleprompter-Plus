import 'dart:async';

import '../services/alignment_engine.dart';
import '../services/asr_transcript_normalizer.dart';
import '../services/asr_service.dart';
import '../services/text_parser.dart';
import 'settings_service.dart';
import 'ws_protocol.dart';
import 'ws_server.dart';

enum AsrSessionStatus { idle, loading, running, paused, error }

/// Owns recognition for the backend. UI clients only receive processed data.
typedef AsrPositionChanged =
    void Function(int currentIndex, {bool allowBackward});

class AsrSessionService {
  AsrSessionService(this._settingsService, this._onCurrentIndexChanged);

  static const unloadDelay = Duration(seconds: 20);
  static const int maxPartialAdvance = 4;
  static const int maxFinalAdvance = 6;

  static int limitAdvance({
    required int currentIndex,
    required int requestedIndex,
    required bool isFinal,
  }) {
    if (requestedIndex < 0 ||
        currentIndex < 0 ||
        requestedIndex <= currentIndex) {
      return requestedIndex;
    }
    final maxAdvance = isFinal ? maxFinalAdvance : maxPartialAdvance;
    return requestedIndex
        .clamp(currentIndex, currentIndex + maxAdvance)
        .toInt();
  }

  final SettingsService _settingsService;
  final AsrPositionChanged _onCurrentIndexChanged;
  final AsrService _asr = AsrService.instance;
  final TeleprompterAlignment _alignment = TeleprompterAlignment();
  WsServer? _server;
  Timer? _unloadTimer;
  Future<void>? _pendingUnload;
  Future<void>? _startOperation;
  String _articleId = '';
  String _transcript = '';
  String _committedTranscript = '';
  String _partialTranscript = '';
  double _rms = 0;
  int _currentIndex = -1;
  AsrSessionStatus _status = AsrSessionStatus.idle;
  String? _error;
  String? _loadedConfigKey;
  DateTime? _lastRmsBroadcastAt;

  void registerHandlers(WsServer server) {
    _server = server;
    server.requests.listen((request) {
      switch (request.message.type) {
        case WsMessageType.asrStart:
          unawaited(_handleStart(server, request));
        case WsMessageType.asrPause:
          unawaited(_handlePause(server, request));
        default:
          break;
      }
    });
  }

  void beginSession({
    required String articleId,
    required String content,
    required int currentIndex,
  }) {
    _articleId = articleId;
    _currentIndex = currentIndex;
    _transcript = '';
    _committedTranscript = '';
    _partialTranscript = '';
    _rms = 0;
    _error = null;
    final alignmentText = TextParser.isHtml(content)
        ? TextParser.parse(
            content,
          ).expand((line) => line.characters).map((char) => char.char).join()
        : content;
    _alignment
      ..setScript(alignmentText)
      ..setCurrentIndex(currentIndex);
    _broadcastStatus();
  }

  /// 手动或自动移动当前字后，同步覆盖对齐锚点。
  void setCurrentIndex(int currentIndex) {
    if (_articleId.isEmpty) return;
    _currentIndex = currentIndex;
    _alignment.setCurrentIndex(currentIndex);
  }

  Future<void> pause() async {
    final startOperation = _startOperation;
    if (startOperation != null) {
      try {
        await startOperation;
      } catch (_) {
        // Start errors are already reflected in ASR status; pause still wins.
      }
    }
    await _asr.stop();
    _rms = 0;
    _status = AsrSessionStatus.paused;
    _broadcastStatus();
  }

  Future<void> endSession() async {
    _unloadTimer?.cancel();
    await pause();
    _unloadTimer = Timer(unloadDelay, () {
      _pendingUnload = _unloadAfterSession();
    });
  }

  Future<void> _unloadAfterSession() async {
    await _asr.unloadModel();
    _loadedConfigKey = null;
    _status = AsrSessionStatus.idle;
    _broadcastStatus();
  }

  Future<void> shutdown() async {
    _unloadTimer?.cancel();
    final startOperation = _startOperation;
    if (startOperation != null) {
      try {
        await startOperation;
      } catch (_) {}
    }
    await _asr.stop();
    await _asr.unloadModel();
    _loadedConfigKey = null;
    _articleId = '';
    _status = AsrSessionStatus.idle;
  }

  Future<void> release() async {
    await shutdown();
    await _asr.release();
  }

  Future<void> start() async {
    final activeOperation = _startOperation;
    if (activeOperation != null) {
      await activeOperation;
      return;
    }
    final operation = _startInternal();
    _startOperation = operation;
    try {
      await operation;
    } finally {
      if (identical(_startOperation, operation)) _startOperation = null;
    }
  }

  Future<void> _startInternal() async {
    if (_articleId.isEmpty) throw StateError('当前没有活动的提词会话');
    if (_status == AsrSessionStatus.running && _asr.isRunning) return;
    _unloadTimer?.cancel();
    await _pendingUnload;
    _pendingUnload = null;
    _error = null;
    _status = AsrSessionStatus.loading;
    _broadcastStatus();
    try {
      final settings = await _settingsService.loadSettings();
      final modelId = settings.asrModelId;
      if (modelId.isEmpty) throw StateError('尚未选择语音识别模型');
      final configKey = [
        modelId,
        settings.asrNumThreads,
        settings.asrRule1MinTrailingSilence,
        settings.asrRule2MinTrailingSilence,
        settings.asrRule3MinUtteranceLength,
      ].join('|');
      AsrService.init();
      if (!_asr.isModelLoaded ||
          _asr.currentModelId != modelId ||
          _loadedConfigKey != configKey) {
        await _asr.loadModel(
          modelId,
          numThreads: settings.asrNumThreads,
          rule1MinTrailingSilence: settings.asrRule1MinTrailingSilence,
          rule2MinTrailingSilence: settings.asrRule2MinTrailingSilence,
          rule3MinUtteranceLength: settings.asrRule3MinUtteranceLength,
        );
        _loadedConfigKey = configKey;
      }
      await _asr.start(
        onPartialResult: (text) => _handleTranscript(text, false),
        onFinalResult: (text) => _handleTranscript(text, true),
        onRmsUpdate: _handleRms,
        inputDeviceId: settings.asrInputDeviceId,
        onError: _handleRecognizerError,
      );
      _status = AsrSessionStatus.running;
      _broadcastStatus();
    } catch (error) {
      _status = AsrSessionStatus.error;
      _error = error.toString();
      _broadcastStatus();
      rethrow;
    }
  }

  Future<void> _handleStart(WsServer server, WsRequest request) async {
    var success = true;
    try {
      await start();
    } catch (_) {
      success = false;
    }
    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.asrStartResponse,
        id: request.message.id,
        data: _statusData(success: success),
      ),
    );
  }

  Future<void> _handlePause(WsServer server, WsRequest request) async {
    await pause();
    server.respond(
      request.clientId,
      WsMessage(
        type: WsMessageType.asrPauseResponse,
        id: request.message.id,
        data: _statusData(success: true),
      ),
    );
  }

  void _handleTranscript(String text, bool isFinal) {
    final trimmed = normalizeAsrTranscript(text.trim());
    if (isFinal) {
      if (trimmed.isNotEmpty) {
        _committedTranscript = appendAsrTranscript(
          _committedTranscript,
          trimmed,
        );
      }
      _partialTranscript = '';
    } else {
      _partialTranscript = trimmed;
    }
    _transcript = composeAsrDisplayText(
      _committedTranscript,
      _partialTranscript,
    );
    final result = _alignment.consumeTranscript(trimmed, isFinal);
    final alignedIndex = limitAdvance(
      currentIndex: _currentIndex,
      requestedIndex: result.index,
      isFinal: isFinal,
    );
    if (alignedIndex >= 0 &&
        (alignedIndex >= _currentIndex || result.meta.allowBackward)) {
      _currentIndex = alignedIndex;
      _onCurrentIndexChanged(
        _currentIndex,
        allowBackward: result.meta.allowBackward,
      );
    }
    _server?.broadcast(
      WsMessage(
        type: WsMessageType.asrResult,
        data: {
          ..._statusData(),
          'segment': trimmed,
          'isFinal': isFinal,
          'allowBackward': result.meta.allowBackward,
        },
      ),
    );
  }

  void _handleRms(double value) {
    _rms = value;
    final now = DateTime.now();
    final previous = _lastRmsBroadcastAt;
    if (previous != null &&
        now.difference(previous) < const Duration(milliseconds: 50)) {
      return;
    }
    _lastRmsBroadcastAt = now;
    _server?.broadcast(
      WsMessage(
        type: WsMessageType.asrStatus,
        data: {
          'articleId': _articleId,
          'status': _status.name,
          'rms': _rms,
          'currentIndex': _currentIndex,
        },
      ),
    );
  }

  void _handleRecognizerError(Object error) {
    _status = AsrSessionStatus.error;
    _error = '麦克风采集失败: $error';
    _rms = 0;
    _broadcastStatus();
  }

  Map<String, dynamic> _statusData({bool? success}) => {
    'success': ?success,
    'articleId': _articleId,
    'status': _status.name,
    'text': _transcript,
    'rms': _rms,
    'currentIndex': _currentIndex,
    'error': ?_error,
  };

  void _broadcastStatus() {
    _server?.broadcast(
      WsMessage(type: WsMessageType.asrStatus, data: _statusData()),
    );
  }
}
