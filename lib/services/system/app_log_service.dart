import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// 应用内日志记录。
///
/// 通过 logger 的自定义输出保存最近日志，并接管现有 [debugPrint]，无需业务代码
/// 重复维护控制台输出和应用内日志两套调用。
class AppLogService {
  AppLogService._() {
    _output.onEvent = _append;
    _logger = Logger(
      filter: ProductionFilter(),
      printer: SimplePrinter(colors: false),
      output: _output,
      level: Level.trace,
    );
  }

  static final AppLogService instance = AppLogService._();
  static const int maxEntries = 2000;

  final _AppLogOutput _output = _AppLogOutput();
  late final Logger _logger;
  final ValueNotifier<List<AppLogEntry>> entries = ValueNotifier(const []);
  bool _installed = false;
  DebugPrintCallback? _originalDebugPrint;

  /// 在 Flutter 初始化后尽早安装异常与 debugPrint 捕获。
  void install() {
    if (_installed) return;
    _installed = true;

    _originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) _logger.d(message);
      _originalDebugPrint?.call(message, wrapWidth: wrapWidth);
    };

    final previousFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      _logger.e(
        details.exceptionAsString(),
        error: details.exception,
        stackTrace: details.stack,
      );
      if (previousFlutterError != null) {
        previousFlutterError(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    final previousPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _logger.e('未处理的异步异常', error: error, stackTrace: stack);
      return previousPlatformError?.call(error, stack) ?? false;
    };
  }

  void clear() => entries.value = const [];

  String exportText() => entries.value.map((entry) => entry.line).join('\n');

  void _append(OutputEvent event) {
    final timestamp = event.origin.time;
    final added = [
      for (final line in event.lines)
        AppLogEntry(timestamp: timestamp, level: event.level, message: line),
      if (event.origin.stackTrace case final stackTrace?)
        for (final line in stackTrace.toString().trim().split('\n'))
          AppLogEntry(timestamp: timestamp, level: event.level, message: line),
    ];
    final next = <AppLogEntry>[...entries.value, ...added];
    if (next.length > maxEntries) {
      next.removeRange(0, next.length - maxEntries);
    }
    entries.value = List.unmodifiable(next);
  }
}

class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  final DateTime timestamp;
  final Level level;
  final String message;

  String get line => '${_formatTime(timestamp)} $message';

  static String _formatTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    String three(int number) => number.toString().padLeft(3, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}.'
        '${three(value.millisecond)}';
  }
}

class _AppLogOutput extends LogOutput {
  void Function(OutputEvent event)? onEvent;

  @override
  void output(OutputEvent event) => onEvent?.call(event);
}
