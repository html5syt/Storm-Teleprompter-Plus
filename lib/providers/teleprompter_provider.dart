import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../models/script_character.dart';
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
class TeleprompterProvider with ChangeNotifier {
  // ─── 核心状态 ──────────────────────────────────────────
  TeleprompterState _state = TeleprompterState.idle;
  int _currentIndex = -1; // 当前高亮字符的原稿索引
  List<ScriptLine> _lines = [];
  String _articleId = '';

  // ─── 自动滚动 ──────────────────────────────────────────
  Timer? _autoScrollTimer;
  int _totalChars = 0;

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
    notifyListeners();
  }

  /// 开始/恢复播放
  void play(AppSettings settings) {
    if (_state == TeleprompterState.idle ||
        _state == TeleprompterState.completed) {
      return;
    }

    _state = TeleprompterState.playing;
    _startAutoScrollIfNeeded(settings);
    _startAsrIfNeeded(settings);
    _scheduleHideControls(settings);
    notifyListeners();
  }

  /// 暂停播放
  void pause(AppSettings settings) {
    _state = TeleprompterState.paused;
    _stopAutoScroll();
    _stopAsr();
    _cancelHideControls();
    _controlsVisible = true;
    notifyListeners();
  }

  /// 切换播放/暂停
  void togglePlayPause(AppSettings settings) {
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
    notifyListeners();
  }

  /// 切换控制面板可见性
  void toggleControls() {
    _controlsVisible = !_controlsVisible;
    notifyListeners();
  }

  /// 显示控制面板（全屏模式下触摸屏幕时）
  void showControls(AppSettings settings) {
    _controlsVisible = true;
    notifyListeners();
    _scheduleHideControls(settings);
  }

  // ─── 自动滚动逻辑 ──────────────────────────────────────

  void _startAutoScrollIfNeeded(AppSettings settings) {
    if (settings.scrollMode != ScrollMode.auto) return;
    _stopAutoScroll();

    // 使用 Timer 实现匀速滚动
    // 每字符间隔 = 60000ms / WPM
    final msPerChar = (60000 / settings.wpm).round();

    _autoScrollTimer = Timer.periodic(
      Duration(milliseconds: msPerChar.clamp(16, 2000)),
      (timer) {
        if (_state != TeleprompterState.playing) return;

        final nextIndex = _currentIndex + 1;
        if (nextIndex >= _totalChars) {
          // 读完自动暂停并重置
          _currentIndex = 0;
          _state = TeleprompterState.completed;
          _stopAutoScroll();
          notifyListeners();
          return;
        }

        _currentIndex = nextIndex;
        notifyListeners();
      },
    );
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
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
        final result = _alignment.consumeTranscript(text, false);
        if (result.index >= 0 && result.index > _currentIndex) {
          _currentIndex = result.index;
          notifyListeners();
        }
      },
      onFinalResult: (text) {
        final result = _alignment.consumeTranscript(text, true);
        if (result.index >= 0) {
          _currentIndex = result.index;
          notifyListeners();
        }
      },
      onRmsUpdate: (rms) {
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
    if (!settings.fullScreenMode || !settings.autoHideUI) return;

    _hideControlsTimer = Timer(
      Duration(seconds: settings.autoHideDelaySeconds),
      () {
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

  @override
  void dispose() {
    _stopAutoScroll();
    _stopAsr();
    _cancelHideControls();
    super.dispose();
  }
}
