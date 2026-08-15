import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../utils/constants.dart';
import 'app_data_directory.dart';
import 'app_log_persistence_base.dart';

typedef AppDataDirectoryProvider = Future<Directory> Function();

class AppLogPersistence implements AppLogPersistenceBackend {
  AppLogPersistence({
    AppDataDirectoryProvider? dataDirectoryProvider,
    DateTime Function()? clock,
  }) : _dataDirectoryProvider = dataDirectoryProvider ?? getAppDataDirectory,
       _usesDefaultDataDirectoryProvider = dataDirectoryProvider == null,
       _clock = clock ?? DateTime.now;

  final AppDataDirectoryProvider _dataDirectoryProvider;
  final bool _usesDefaultDataDirectoryProvider;
  final DateTime Function() _clock;

  RandomAccessFile? _file;
  String? _currentLogPath;
  String? _directoryFallbackMessage;

  @override
  String? get currentLogPath => _currentLogPath;

  @override
  List<String> get startupDetails => [
    if (_directoryFallbackMessage case final message?) message,
    'Operating system: ${Platform.operatingSystem}',
    'OS version: ${_singleLine(Platform.operatingSystemVersion)}',
    'Dart runtime: ${_singleLine(Platform.version)}',
    'Locale: ${Platform.localeName}',
    'Processors: ${Platform.numberOfProcessors}',
    'Executable: ${Platform.resolvedExecutable}',
  ];

  @override
  Future<String?> startSession() async {
    if (_currentLogPath != null) return _currentLogPath;

    final startedAt = _clock();
    final logDirectory = await _resolveLogDirectory();
    final logFile = _createUniqueLogFile(logDirectory, startedAt);
    _file = logFile.openSync(mode: FileMode.append);
    _currentLogPath = logFile.path;
    _pruneOldLogs(logDirectory, currentLogPath: logFile.path);
    return logFile.path;
  }

  @override
  void appendLines(Iterable<String> lines) {
    final file = _file;
    if (file == null) return;
    final text = lines.join('\n');
    if (text.isEmpty) return;
    file.writeStringSync('$text\n');
    file.flushSync();
  }

  @override
  void replaceLines(Iterable<String> lines) {
    final file = _file;
    if (file == null) return;
    file.truncateSync(0);
    file.setPositionSync(0);
    final text = lines.join('\n');
    if (text.isNotEmpty) file.writeStringSync('$text\n');
    file.flushSync();
  }

  @override
  Future<void> close() async {
    final file = _file;
    _file = null;
    if (file != null) file.closeSync();
  }

  Future<Directory> _resolveLogDirectory() async {
    try {
      final dataDirectory = await _dataDirectoryProvider();
      final logDirectory = Directory(
        p.join(dataDirectory.path, StorageConstants.logDirectoryName),
      );
      await logDirectory.create(recursive: true);
      return logDirectory;
    } catch (error) {
      if (!_usesDefaultDataDirectoryProvider) rethrow;

      final supportDirectory = await getApplicationSupportDirectory();
      final logDirectory = Directory(
        p.join(supportDirectory.path, StorageConstants.logDirectoryName),
      );
      await logDirectory.create(recursive: true);
      _directoryFallbackMessage =
          'Primary application data directory was unavailable; '
          'using platform application support directory. Error: $error';
      return logDirectory;
    }
  }

  File _createUniqueLogFile(Directory directory, DateTime startedAt) {
    final timestamp = _formatFileTimestamp(startedAt);
    var suffix = 0;
    while (true) {
      final suffixText = suffix == 0
          ? ''
          : '-${suffix.toString().padLeft(3, '0')}';
      final file = File(
        p.join(
          directory.path,
          '${StorageConstants.startupLogFilePrefix}$timestamp$suffixText.log',
        ),
      );
      try {
        file.createSync(exclusive: true);
        return file;
      } on FileSystemException {
        if (!file.existsSync()) rethrow;
        suffix++;
      }
    }
  }

  void _pruneOldLogs(Directory directory, {required String currentLogPath}) {
    try {
      final currentPath = p.normalize(p.absolute(currentLogPath));
      final previousLogs = directory
          .listSync(followLinks: false)
          .whereType<File>()
          .where(_isManagedLogFile)
          .where((file) => p.normalize(p.absolute(file.path)) != currentPath)
          .toList();
      previousLogs.sort(_compareNewestFirst);

      final previousLogsToKeep = StorageConstants.maxStartupLogFiles - 1;
      for (final file in previousLogs.skip(previousLogsToKeep)) {
        try {
          file.deleteSync();
        } on FileSystemException {
        }
      }
    } on FileSystemException {
    }
  }

  bool _isManagedLogFile(File file) {
    final name = p.basename(file.path);
    return name.startsWith(StorageConstants.startupLogFilePrefix) &&
        name.endsWith('.log');
  }

  int _compareNewestFirst(File left, File right) {
    final modifiedComparison = right.lastModifiedSync().compareTo(
      left.lastModifiedSync(),
    );
    if (modifiedComparison != 0) return modifiedComparison;
    return p.basename(right.path).compareTo(p.basename(left.path));
  }

  static String _formatFileTimestamp(DateTime value) {
    String digits(int number, int width) =>
        number.toString().padLeft(width, '0');
    return '${digits(value.year, 4)}${digits(value.month, 2)}'
        '${digits(value.day, 2)}-${digits(value.hour, 2)}'
        '${digits(value.minute, 2)}${digits(value.second, 2)}-'
        '${digits(value.millisecond, 3)}';
  }

  static String _singleLine(String value) =>
      value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
}
