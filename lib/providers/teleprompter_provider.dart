import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/app_settings.dart';
import '../models/script_character.dart';
import '../providers/settings_provider.dart';
import '../services/alignment_engine.dart';
import '../services/asr_service.dart';
import '../services/text_parser.dart';
import '../utils/constants.dart';

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
/// 自动滚动使用 RAF (requestAnimationFrame) 时间累加器模式,
/// 与原始 Web 项目保持一致，确保滚动速度精准。
class TeleprompterProvider with ChangeNotifier {
  // ─── 核心状态 ──────────────────────────────────────────
  TeleprompterState _state = TeleprompterState.idle;
  int _currentIndex = -1; // 当前高亮字符的原稿索引
  List<ScriptLine> _lines = [];
  String _articleId = '';

  // ─── 自动滚动（RAF 时间累加器） ────────────────────────
  int _totalChars = 0;
  double _accumulator = 0.0; // 时间累加器（毫秒）
  double _lastFrameTime = 0.0; // 上一帧时间戳（毫秒）
  Ticker? _ticker;

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

  // ─── Getters ────────────────────────────────────────────
  TeleprompterState get state => _state;
  int get currentIndex => _currentIndex;
  List<ScriptLine> get lines => _lines;
  String get articleId => _articleId;
  double get rms => _rms;
  bool get controlsVisible => _controlsVisible;
  int get totalChars => _totalChars;
  TeleprompterAlignment get alignment => _alignment;

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
    // 有 currentIndex 时始终使用字符索引计算，保证各模式间进度一致
    if (_currentIndex >= 0 && _totalChars > 0) {
      return (_currentIndex + 1) / _totalChars;
    }
    return _manualProgress;
  }

  // ─── 手动滚动进度跟踪 ─────────────────────────────────
  double _manualProgress = 0.0;

  double get manualProgress => _manualProgress;

  /// 设置手动滚动进度（仅 manual 模式使用）
  void setManualProgress(double value) {
    _manualProgress = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// 加载稿件内容
  void loadScript(String articleId, String content) {
    _articleId = articleId;

    // 解析文本为行
    if (TextParser.isHtml(content)) {
      _lines = TextParser.parse(content);
    } else {
      _lines = TextParser.parsePlainText(content);
    }

    // 计算总字符数
    _totalChars = _lines.fold(0, (sum, line) => sum + line.characters.length);

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
        _state == TeleprompterState.completed) {
      return;
    }

    _state = TeleprompterState.playing;
    _playStartTime = DateTime.now();
    _startAutoScrollIfNeeded(settings);
    _startAsrIfNeeded(settings);
    _scheduleHideControls(settings);
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
    _currentIndex = rawIndex;
    _alignment.setCurrentIndex(rawIndex);
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
    notifyListeners();
  }

  /// 快退 10 行
  void rewind(AppSettings settings) {
    final target = (_currentIndex - 10).clamp(-1, _totalChars - 1);
    _currentIndex = target;
    _alignment.setCurrentIndex(target);
    if (_state == TeleprompterState.playing &&
        settings.scrollMode == ScrollMode.auto) {
      _stopAutoScroll();
      _startAutoScrollIfNeeded(settings);
    }
    notifyListeners();
  }

  /// 快进 10 行
  void forward(AppSettings settings) {
    final target = (_currentIndex + 10).clamp(-1, _totalChars - 1);
    _currentIndex = target;
    _alignment.setCurrentIndex(target);
    if (_state == TeleprompterState.playing &&
        settings.scrollMode == ScrollMode.auto) {
      _stopAutoScroll();
      _startAutoScrollIfNeeded(settings);
    }
    notifyListeners();
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

  // ─── 自动滚动逻辑（RAF 时间累加器） ───────────────────

  void _startAutoScrollIfNeeded(AppSettings settings) {
    if (settings.scrollMode != ScrollMode.auto) return;
    _stopAutoScroll();

    _accumulator = 0.0;
    _lastFrameTime = 0.0;

    _ticker = Ticker((elapsed) {
      if (_state != TeleprompterState.playing) return;

      final currentTime = elapsed.inMilliseconds.toDouble();

      if (_lastFrameTime == 0.0) {
        _lastFrameTime = currentTime;
        return;
      }

      final deltaTime = currentTime - _lastFrameTime;
      _lastFrameTime = currentTime;

      // 每字符间隔 = 60000ms / WPM
      final msPerChar = 60000.0 / settings.wpm;
      _accumulator += deltaTime;

      if (_accumulator >= msPerChar) {
        final charsToAdvance = (_accumulator / msPerChar).floor();
        _accumulator %= msPerChar;

        final newIndex = (_currentIndex + charsToAdvance).clamp(
          0,
          _totalChars - 1,
        );

        if (newIndex >= _totalChars - 1) {
          // 播完后回到开头并停止（与原版行为一致）
          _currentIndex = -1;
          _state = TeleprompterState.paused;
          _stopAutoScroll();
          _playStartTime = null;
          _elapsedBeforePause = Duration.zero;
          notifyListeners();
          return;
        }

        _currentIndex = newIndex;
        notifyListeners();
      }
    });

    _ticker!.start();
  }

  void _stopAutoScroll() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _accumulator = 0.0;
    _lastFrameTime = 0.0;
  }

  /// 滚轮动态调速（自动模式下，鼠标滚轮上下滚动改变 WPM）
  ///
  /// [delta] 为正数表示向下滚动（加速），负数表示向上滚动（减速）
  void adjustSpeedByWheel(double delta, SettingsProvider settingsProvider) {
    if (_state != TeleprompterState.playing) return;
    final merged = settingsProvider.mergedSettings;
    if (merged.scrollMode != ScrollMode.auto) return;

    // 每次滚轮事件调整 WPM：小步 ±5，大步 ±15
    final step = delta.abs() > 0.5 ? 15 : 5;
    final direction = delta > 0 ? 1 : -1;
    final newWpm = (merged.wpm + step * direction).clamp(
      AppConstants.minWpm,
      AppConstants.maxWpm,
    );

    if (newWpm != merged.wpm) {
      settingsProvider.setWpm(newWpm);
      // 重启 ticker 使新 WPM 立即生效
      _stopAutoScroll();
      _startAutoScrollIfNeeded(settingsProvider.mergedSettings);
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
          notifyListeners();
        }
      },
      onFinalResult: (text) {
        if (!hasListeners) return;
        final result = _alignment.consumeTranscript(text, true);
        if (result.index >= 0) {
          _currentIndex = result.index;
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

  /// 获取当前索引对应的字符信息
  ScriptCharacter? get currentCharacter {
    if (_currentIndex < 0 || _lines.isEmpty) return null;
    for (final line in _lines) {
      for (final char in line.characters) {
        if (char.rawIndex == _currentIndex) return char;
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
