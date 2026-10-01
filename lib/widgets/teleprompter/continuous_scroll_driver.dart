import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 使用帧时间积分像素位移，不依赖字符数量、帧率或按行动画。
class ContinuousScrollDriver with WidgetsBindingObserver {
  final ScrollController controller;
  final void Function(bool atStart) onBoundary;
  late final Ticker _ticker;
  Duration? _previousFrame;
  double _speed = 0;
  bool _playing = false;
  bool _foreground = true;

  ContinuousScrollDriver({
    required TickerProvider vsync,
    required this.controller,
    required this.onBoundary,
  }) {
    _ticker = vsync.createTicker(_tick);
    WidgetsBinding.instance.addObserver(this);
  }

  /// 调速不重置已累计的位置，暂停和零速时彻底停止帧回调。
  void update({required bool playing, required double speed}) {
    _playing = playing;
    _speed = speed.isFinite ? speed : 0;
    _refreshTicker();
  }

  /// 恢复前台时重新计时，避免把后台时间转换成大幅跳动。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _refreshTicker();
  }

  /// 只在有有效速度且前台播放时请求绘制帧。
  void _refreshTicker() {
    final active = _playing && _speed != 0 && _foreground;
    if (active && !_ticker.isActive) {
      _previousFrame = null;
      _ticker.start();
    } else if (!active && _ticker.isActive) {
      _ticker.stop();
      _previousFrame = null;
    }
  }

  /// 每帧只改变视口偏移，不触发字符跟随定位。
  void _tick(Duration elapsed) {
    final previous = _previousFrame;
    _previousFrame = elapsed;
    if (previous == null ||
        !controller.hasClients ||
        !controller.position.hasContentDimensions)
      return;
    final position = controller.position;
    final delta =
        (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond;
    final target = (position.pixels + _speed * delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    controller.jumpTo(target);
    final atStart = _speed < 0 && target <= position.minScrollExtent;
    final atEnd = _speed > 0 && target >= position.maxScrollExtent;
    if (atStart || atEnd) {
      _playing = false;
      _refreshTicker();
      onBoundary(atStart);
    }
  }

  /// 清理帧和生命周期监听，不留下后台滚动任务。
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
  }
}
