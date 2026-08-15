import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import 'app_log_persistence.dart';
import 'app_log_persistence_base.dart';

class AppLogService {
  AppLogService._([AppLogPersistenceBackend? persistence])
    : _persistence = persistence ?? AppLogPersistence() {
    _output.onEvent = _append;
    _logger = Logger(
      filter: ProductionFilter(),
      printer: SimplePrinter(colors: false),
      output: _output,
      level: Level.trace,
    );
  }

  @visibleForTesting
  AppLogService.forTesting(AppLogPersistenceBackend persistence)
    : this._(persistence);

  static final AppLogService instance = AppLogService._();

  final _AppLogOutput _output = _AppLogOutput();
  final AppLogPersistenceBackend _persistence;
  late final Logger _logger;
  final ValueNotifier<List<AppLogEntry>> entries = ValueNotifier(const []);
  bool _installed = false;
  bool _fileLoggingActive = false;
  DebugPrintCallback? _originalDebugPrint;
  Future<void>? _startSessionFuture;

  String? get currentLogPath => _persistence.currentLogPath;

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

  Future<void> startSession() =>
      _startSessionFuture ??= _startPersistentSession();

  void info(String message) => _logger.i(message);

  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);

  Future<void> close() => _persistence.close();

  void clear() {
    if (_fileLoggingActive) {
      try {
        _persistence.replaceLines(const []);
      } catch (error, stackTrace) {
        _originalDebugPrint?.call(
          '[AppLog] Failed to clear startup log: $error\n$stackTrace',
        );
        return;
      }
    }
    entries.value = const [];
  }

  String exportText() => entries.value.map((entry) => entry.line).join('\n');

  Future<void> _startPersistentSession() async {
    try {
      final path = await _persistence.startSession();
      if (path == null) return;

      _persistence.appendLines(entries.value.map((entry) => entry.line));
      _fileLoggingActive = true;
      _logger.i('[AppLog] Startup log file: $path');
      for (final detail in _persistence.startupDetails) {
        _logger.i('[AppLog] $detail');
      }
    } catch (error, stackTrace) {
      _fileLoggingActive = false;
      _logger.e(
        '[AppLog] Failed to create startup log file',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

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
    entries.value = List.unmodifiable(next);

    if (_fileLoggingActive) {
      try {
        _persistence.appendLines(added.map((entry) => entry.line));
      } catch (error, stackTrace) {
        _fileLoggingActive = false;
        _originalDebugPrint?.call(
          '[AppLog] Failed to append startup log: $error\n$stackTrace',
        );
      }
    }
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
