import 'dart:async';
import 'package:flutter/material.dart';
import '../backend/ws_protocol.dart';
import '../models/app_settings.dart';
import '../models/script_character.dart';
import '../providers/settings_provider.dart';
import '../providers/connection_provider.dart';
import '../services/alignment_engine.dart';
import '../services/asr_service.dart';
import '../services/text_parser.dart';

/// 提词器运行状态
enum TeleprompterState {
  /// 空闲（未加载稿件）
  idle,

  /// 已加载但暂停
  paused,

  /// 正在播放/滚动
  playing,

  /// 朗读完毕
  completed,
}

/// 提词器状态管理
///
/// 管理提词器的滚动、ASR 对齐、文本渲染等核心逻辑。
/// 自动滚动使用周期计时器累计真实时间，避免帧率变化影响滚动速度。
class TeleprompterProvider with ChangeNotifier {
  // ─── 核心状态 ──────────────────────────────────────────
  TeleprompterState _state = TeleprompterState.idle;
  int _currentIndex = -1; // 当前高亮字符的原稿索引
  List<ScriptLine> _lines = [];
  String _articleId = '';

  // ─── 自动滚动 ──────────────────────────────────────────
  int _totalChars = 0;
  final List<int> _charRawIndices = <int>[];
  double _accumulator = 0.0; // 时间累加器（毫秒）
  Timer? _autoScrollTimer;
  DateTime? _lastAutoTickAt;
  DateTime? _lastElapsedNotifyAt;
  int? _activeAutoWpm;
  ScrollMode? _activeAutoMode;

  // ─── 播放时间跟踪 ──────────────────────────────────────
  DateTime? _playStartTime;
  Duration _elapsedBeforePause = Duration.zero;

  // ─── ASR ────────────────────────────────────────────────
  final TeleprompterAlignment _alignment = TeleprompterAlignment();
  final AsrService _asrService = AsrService.instance;
  double _rms = 0;

  // ─── 全屏/控制面板 ─────────────────────────────────────
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;

  // ─── WebSocket 同步 ─────────────────────────────────────
  ConnectionProvider? _connection;
  int _lastRealtimeSyncMs = 0;

  // ─── Getters ────────────────────────────────────────────
  TeleprompterState get state => _state;
  int get currentIndex => _currentIndex;
  List<ScriptLine> get lines => _lines;
  String get articleId => _articleId;
  double get rms => _rms;
  bool get controlsVisible => _controlsVisible;

  /// 是否正在播放（任何模式）
  bool get isPlaying => _state == TeleprompterState.playing;

  /// 当前已用时间
  Duration get elapsed {
    if (_playStartTime != null) {
      return _elapsedBeforePause + DateTime.now().difference(_playStartTime!);
    }
    return _elapsedBeforePause;
  }

  /// 当前阅读进度 (0.0 ~ 1.0)
  double get progress {
    // currentIndex 是原稿 rawIndex；进度使用可见字符序号换算。
    final ordinal = _ordinalForRawIndex(_currentIndex);
    if (ordinal >= 0 && _totalChars > 0) {
      return (ordinal + 1) / _totalChars;
    }
    return _viewportProgress;
  }

  // ─── 视口滚动进度跟踪 ─────────────────────────────────
  double _viewportProgress = 0.0;

  /// 设置视口滚动进度，用于当前字尚未映射时的进度回退。
  void setViewportProgress(double value) {
    final next = value.clamp(0.0, 1.0).toDouble();
    if ((_viewportProgress - next).abs() < 0.0005) return;
    _viewportProgress = next;
    notifyListeners();
  }

  /// 绑定 WebSocket 连接（用于多端同步）
  void bindConnection(ConnectionProvider connection) {
    _connection = connection;
  }

  void applyRemoteSync({
    required int currentIndex,
    required bool isPlaying,
    required AppSettings settings,
  }) {
    if (_state == TeleprompterState.idle || _totalChars == 0) return;

    final normalizedIndex = currentIndex < 0
        ? -1
        : _normalizeRawIndex(currentIndex);
    _currentIndex = normalizedIndex;
    if (_currentIndex >= 0) {
      _alignment.setCurrentIndex(_currentIndex);
    } else {
      _alignment.reset();
    }

    if (isPlaying) {
      if (_state != TeleprompterState.playing) {
        _state = TeleprompterState.playing;
        _playStartTime = DateTime.now();
      }
      _stopAutoScroll();
      _stopAsr();
      _scheduleHideControls(settings);
    } else {
      if (_state == TeleprompterState.playing && _playStartTime != null) {
        _elapsedBeforePause += DateTime.now().difference(_playStartTime!);
      }
      _state = TeleprompterState.paused;
      _playStartTime = null;
      _stopAutoScroll();
      _stopAsr();
      _cancelHideControls();
      _controlsVisible = true;
    }

    notifyListeners();
  }

  /// 同步当前状态到后端
  void _syncToBackend({bool reliable = false}) {
    if (_connection == null ||
        !_connection!.isConnected ||
        !_connection!.isLocal) {
      return;
    }
    if (!reliable && _connection!.remoteDeviceIds.isEmpty) {
      return;
    }
    final data = {
      'currentIndex': _currentIndex,
      'isPlaying': isPlaying,
      'articleId': _articleId,
    };
    if (reliable) {
      _lastRealtimeSyncMs = DateTime.now().millisecondsSinceEpoch;
      try {
        unawaited(
          _connection!
              .request(
                WsMessageType.teleprompterSync,
                data: data,
                timeout: const Duration(milliseconds: 900),
              )
              .then<void>(
                (_) {},
                onError: (Object error, StackTrace stackTrace) {
                  debugPrint('[TeleprompterProvider] 可靠同步失败: $error');
                  _sendSyncMessage(data);
                },
              ),
        );
      } catch (error) {
        debugPrint('[TeleprompterProvider] 启动可靠同步失败: $error');
      }
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastRealtimeSyncMs < 50) return;
    _lastRealtimeSyncMs = nowMs;

    _sendSyncMessage(data);
  }

  void _sendSyncMessage(Map<String, dynamic> data) {
    try {
      _connection?.send(
        WsMessage(type: WsMessageType.teleprompterSync, data: data),
      );
    } catch (error) {
      debugPrint('[TeleprompterProvider] 同步发送失败: $error');
    }
  }

  void _rebuildRawIndexMap() {
    _charRawIndices.clear();
    for (final line in _lines) {
      for (final char in line.characters) {
        _charRawIndices.add(char.rawIndex);
      }
    }
    _totalChars = _charRawIndices.length;
  }

  int _rawIndexAtOrdinal(int ordinal) {
    if (_charRawIndices.isEmpty || ordinal < 0) return -1;
    final safe = ordinal.clamp(0, _charRawIndices.length - 1).toInt();
    return _charRawIndices[safe];
  }

  int _ordinalForRawIndex(int rawIndex) {
    if (_charRawIndices.isEmpty || rawIndex < 0) return -1;

    var low = 0;
    var high = _charRawIndices.length - 1;
    while (low <= high) {
      final mid = low + ((high - low) >> 1);
      final value = _charRawIndices[mid];
      if (value == rawIndex) return mid;
      if (value < rawIndex) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    if (low >= _charRawIndices.length) return _charRawIndices.length - 1;
    return low;
  }

  int _normalizeRawIndex(int rawIndex) {
    return _rawIndexAtOrdinal(_ordinalForRawIndex(rawIndex));
  }

  /// 加载稿件内容
  void loadScript(String articleId, String content) {
    _stopAutoScroll();
    _stopAsr();
    _articleId = articleId;

    // 解析文本为行
    if (TextParser.isHtml(content)) {
      _lines = TextParser.parse(content);
    } else {
      _lines = TextParser.parsePlainText(content);
    }

    // 建立可见字符序号 -> 原稿 rawIndex 映射。
    _rebuildRawIndexMap();

    // 设置对齐引擎
    _alignment.setScript(content);
    _alignment.reset();

    _currentIndex = -1;
    _state = _lines.isEmpty ? TeleprompterState.idle : TeleprompterState.paused;
    _playStartTime = null;
    _elapsedBeforePause = Duration.zero;
    notifyListeners();
  }

  /// 开始/恢复播放
  void play(AppSettings settings) {
    if (_state == TeleprompterState.idle ||
        _state == TeleprompterState.completed ||
        _totalChars == 0) {
      return;
    }

    _state = TeleprompterState.playing;
    _playStartTime = DateTime.now();
    _startAutoScrollIfNeeded(settings);
    _startAsrIfNeeded(settings);
    _scheduleHideControls(settings);
    _syncToBackend(reliable: true);
    notifyListeners();
  }

  /// 暂停播放
  void pause(AppSettings settings) {
    _state = TeleprompterState.paused;
    if (_playStartTime != null) {
      _elapsedBeforePause += DateTime.now().difference(_playStartTime!);
      _playStartTime = null;
    }
    _stopAutoScroll();
    _stopAsr();
    _cancelHideControls();
    _controlsVisible = true;
    _syncToBackend(reliable: true);
    notifyListeners();
  }

  /// 切换播放/暂停
  void togglePlayPause(AppSettings settings) {
    if (_state == TeleprompterState.completed) {
      reset();
      play(settings);
      return;
    }
    if (isPlaying) {
      pause(settings);
    } else {
      play(settings);
    }
  }

  /// 手动设置当前索引（点击跳转）
  void setCurrentIndex(int rawIndex) {
    _currentIndex = _normalizeRawIndex(rawIndex);
    _alignment.setCurrentIndex(_currentIndex);
    _syncToBackend();
    notifyListeners();
  }

  /// 重置到开头
  void reset() {
    _stopAutoScroll();
    _stopAsr();
    _currentIndex = -1;
    _alignment.reset();
    _state = _lines.isEmpty ? TeleprompterState.idle : TeleprompterState.paused;
    _controlsVisible = true;
    _playStartTime = null;
    _elapsedBeforePause = Duration.zero;
    _syncToBackend();
    notifyListeners();
  }

  /// 后退一个字
  void rewind(AppSettings settings) {
    if (_totalChars == 0) return;
    final currentOrdinal = _ordinalForRawIndex(_currentIndex);
    final targetOrdinal = currentOrdinal <= 0 ? 0 : currentOrdinal - 1;
    final target = _rawIndexAtOrdinal(targetOrdinal);
    _currentIndex = target;
    _alignment.setCurrentIndex(target);
    if (_state == TeleprompterState.playing &&
        settings.scrollMode == ScrollMode.auto) {
      _stopAutoScroll();
      _startAutoScrollIfNeeded(settings);
    }
    _syncToBackend();
    notifyListeners();
  }

  /// 前进一个字
  void forward(AppSettings settings) {
    final currentOrdinal = _ordinalForRawIndex(_currentIndex);
    final targetOrdinal = currentOrdinal < 0 ? 0 : currentOrdinal + 1;
    final target = _rawIndexAtOrdinal(targetOrdinal);
    _currentIndex = target;
    _alignment.setCurrentIndex(target);
    if (_state == TeleprompterState.playing &&
        settings.scrollMode == ScrollMode.auto) {
      _stopAutoScroll();
      _startAutoScrollIfNeeded(settings);
    }
    _syncToBackend();
    notifyListeners();
  }

  /// 重置到开头（长按后退按钮触发）
  void resetToStart() {
    _currentIndex = -1;
    _alignment.reset();
    _syncToBackend();
    notifyListeners();
  }

  /// 重置到结尾（长按前进按钮触发）
  void resetToEnd() {
    if (_totalChars > 0) {
      _currentIndex = _charRawIndices.last;
      _alignment.setCurrentIndex(_currentIndex);
      _syncToBackend();
      notifyListeners();
    }
  }

  /// 切换控制面板可见性
  void toggleControls() {
    _controlsVisible = !_controlsVisible;
    notifyListeners();
  }

  /// 显示控制面板（仅在播放状态时调度自动隐藏）
  void showControls(AppSettings settings) {
    _controlsVisible = true;
    notifyListeners();
    // 仅在播放状态时调度自动隐藏，暂停/空闲时不隐藏
    if (_state == TeleprompterState.playing) {
      _scheduleHideControls(settings);
    }
  }

  void refreshAutoScrollSettings(AppSettings settings) {
    final changed =
        _activeAutoWpm != settings.wpm ||
        _activeAutoMode != settings.scrollMode;

    if (_state != TeleprompterState.playing) {
      _rememberAutoScrollSettings(settings);
      return;
    }

    if (settings.scrollMode != ScrollMode.auto) {
      if (_autoScrollTimer != null) _stopAutoScroll();
      _rememberAutoScrollSettings(settings);
      return;
    }

    if (changed || _autoScrollTimer == null) {
      _startAutoScrollIfNeeded(settings);
    }
  }

  // ─── 自动滚动逻辑 ──────────────────────────────────────

  void _startAutoScrollIfNeeded(AppSettings settings) {
    _rememberAutoScrollSettings(settings);
    if (settings.scrollMode != ScrollMode.auto) return;
    _stopAutoScroll();

    _accumulator = 0.0;
    _lastAutoTickAt = null;
    _lastElapsedNotifyAt = DateTime.now();

    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_state != TeleprompterState.playing) {
        _stopAutoScroll();
        return;
      }

      final now = DateTime.now();
      final lastTick = _lastAutoTickAt;
      _lastAutoTickAt = now;

      if (lastTick == null) return;
      var shouldNotify = false;
      var shouldSync = false;

      // 每字符间隔 = 60000ms / WPM
      if (settings.wpm > 0) {
        final deltaTime = now.difference(lastTick).inMicroseconds / 1000.0;
        final msPerChar = 60000.0 / settings.wpm;
        _accumulator += deltaTime;

        if (_accumulator >= msPerChar) {
          final charsToAdvance = (_accumulator / msPerChar).floor();
          _accumulator %= msPerChar;

          final currentOrdinal = _ordinalForRawIndex(_currentIndex);
          final nextOrdinal =
              ((currentOrdinal < 0 ? -1 : currentOrdinal) + charsToAdvance)
                  .clamp(0, _totalChars - 1)
                  .toInt();

          if (nextOrdinal >= _totalChars - 1) {
            _currentIndex = _rawIndexAtOrdinal(_totalChars - 1);
            if (_playStartTime != null) {
              _elapsedBeforePause += now.difference(_playStartTime!);
            }
            _state = TeleprompterState.completed;
            _stopAutoScroll();
            _playStartTime = null;
            notifyListeners();
            _syncToBackend();
            return;
          }

          _currentIndex = _rawIndexAtOrdinal(nextOrdinal);
          shouldNotify = true;
          shouldSync = true;
        }
      }

      final lastElapsedNotify = _lastElapsedNotifyAt;
      if (!shouldNotify &&
          lastElapsedNotify != null &&
          now.difference(lastElapsedNotify) >= const Duration(seconds: 1)) {
        shouldNotify = true;
      }

      if (shouldNotify) {
        _lastElapsedNotifyAt = now;
        notifyListeners();
      }
      if (shouldSync) {
        _syncToBackend();
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _accumulator = 0.0;
    _lastAutoTickAt = null;
    _lastElapsedNotifyAt = null;
  }

  void _rememberAutoScrollSettings(AppSettings settings) {
    _activeAutoWpm = settings.wpm;
    _activeAutoMode = settings.scrollMode;
  }

  /// 滚轮动态调速（自动模式下，鼠标滚轮上下滚动改变 WPM）
  ///
  /// [delta] 为正数表示向下滚动（加速），负数表示向上滚动（减速）
  void adjustSpeedByWheel(
    double delta,
    SettingsProvider settingsProvider, {
    int stepMultiplier = 1,
  }) {
    if (_state != TeleprompterState.playing) return;
    final merged = settingsProvider.mergedSettings;
    if (merged.scrollMode != ScrollMode.auto) return;

    // 每次滚轮事件调整 WPM：小步 ±5，大步 ±15
    final step = (delta.abs() > 0.5 ? 15 : 5) * stepMultiplier;
    final direction = delta > 0 ? 1 : -1;
    final newWpm = (merged.wpm + step * direction).clamp(0, 1 << 30).toInt();

    if (newWpm != merged.wpm) {
      final runtimeSettings = merged.copyWith(wpm: newWpm);
      settingsProvider.setWpm(newWpm);
      // 重启自动滚动计时器，使新 WPM 立即生效。
      _stopAutoScroll();
      _startAutoScrollIfNeeded(runtimeSettings);
    }
  }

  // ─── ASR 逻辑 ──────────────────────────────────────────

  void _startAsrIfNeeded(AppSettings settings) {
    if (settings.scrollMode != ScrollMode.asr) return;

    if (!_asrService.isModelLoaded) {
      debugPrint('[Teleprompter] ASR 模型未加载，无法启动语音跟随');
      return;
    }

    _asrService.start(
      onPartialResult: (text) {
        if (!hasListeners) return;
        final result = _alignment.consumeTranscript(text, false);
        if (result.index >= 0 && result.index > _currentIndex) {
          _currentIndex = result.index;
          _syncToBackend();
          notifyListeners();
        }
      },
      onFinalResult: (text) {
        if (!hasListeners) return;
        final result = _alignment.consumeTranscript(text, true);
        if (result.index >= 0) {
          _currentIndex = result.index;
          _syncToBackend();
          notifyListeners();
        }
      },
      onRmsUpdate: (rms) {
        if (!hasListeners) return;
        _rms = rms;
        notifyListeners();
      },
    );
  }

  void _stopAsr() {
    _asrService.stop();
    _rms = 0;
  }

  // ─── 全屏自动隐藏 ──────────────────────────────────────

  void _scheduleHideControls(AppSettings settings) {
    _cancelHideControls();
    if (!settings.autoHideUI) return;

    _hideControlsTimer = Timer(
      Duration(seconds: settings.autoHideDelaySeconds),
      () {
        if (!hasListeners) return; // 安全：没有监听者时跳过
        _controlsVisible = false;
        notifyListeners();
      },
    );
  }

  void _cancelHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = null;
  }

  /// 获取指定索引的字符在行中的位置信息
  /// 返回 (lineIndex, charIndexInLine) 或 null
  (int, int)? getCharPosition(int rawIndex) {
    for (int lineIdx = 0; lineIdx < _lines.length; lineIdx++) {
      final line = _lines[lineIdx];
      for (int charIdx = 0; charIdx < line.characters.length; charIdx++) {
        if (line.characters[charIdx].rawIndex == rawIndex) {
          return (lineIdx, charIdx);
        }
      }
    }
    return null;
  }

  /// 停止所有活动（不触发通知，用于页面销毁时安全清理）
  void stopAll() {
    _stopAutoScroll();
    _stopAsr();
    _cancelHideControls();
    _state = TeleprompterState.paused;
    _controlsVisible = true;
    _playStartTime = null;
    _elapsedBeforePause = Duration.zero;
    // 不调用 notifyListeners()，避免 defunct 元素异常
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _stopAsr();
    _cancelHideControls();
    super.dispose();
  }
}
