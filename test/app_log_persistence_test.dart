import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:storm_teleprompter_plus/services/system/app_log_persistence_io.dart';
import 'package:storm_teleprompter_plus/services/system/app_log_service.dart';
import 'package:storm_teleprompter_plus/utils/constants.dart';

void main() {
  test(
    'creates one launch log and supports replacing its complete contents',
    () async {
      final temp = await Directory.systemTemp.createTemp('storm_app_log_test_');
      final persistence = AppLogPersistence(
        dataDirectoryProvider: () async => temp,
        clock: () => DateTime(2026, 8, 9, 14, 5, 6, 7),
      );
      addTearDown(() async {
        await persistence.close();
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      final path = await persistence.startSession();
      expect(
        p.dirname(path!),
        p.join(temp.path, StorageConstants.logDirectoryName),
      );
      expect(
        p.basename(path),
        'storm-teleprompter-startup-20260809-140506-007.log',
      );

      persistence.appendLines(const ['first', 'second']);
      expect(await File(path).readAsString(), 'first\nsecond\n');

      persistence.replaceLines(const ['replacement']);
      expect(await File(path).readAsString(), 'replacement\n');
    },
  );

  test(
    'keeps the current launch and six newest previous launch logs',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'storm_app_log_rotation_test_',
      );
      final logDirectory = Directory(
        p.join(temp.path, StorageConstants.logDirectoryName),
      );
      await logDirectory.create(recursive: true);
      final baseTime = DateTime(2026, 8, 1);
      late File oldest;
      for (var index = 0; index < 7; index++) {
        final file = File(
          p.join(
            logDirectory.path,
            '${StorageConstants.startupLogFilePrefix}previous-$index.log',
          ),
        );
        await file.writeAsString('previous $index');
        await file.setLastModified(baseTime.add(Duration(days: index)));
        if (index == 0) oldest = file;
      }
      final unrelated = File(p.join(logDirectory.path, 'notes.log'));
      await unrelated.writeAsString('keep me');

      final persistence = AppLogPersistence(
        dataDirectoryProvider: () async => temp,
        clock: () => DateTime(2026, 8, 9),
      );
      addTearDown(() async {
        await persistence.close();
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      final currentPath = await persistence.startSession();
      final managedLogs = logDirectory
          .listSync()
          .whereType<File>()
          .where(
            (file) => p
                .basename(file.path)
                .startsWith(StorageConstants.startupLogFilePrefix),
          )
          .toList();

      expect(managedLogs, hasLength(StorageConstants.maxStartupLogFiles));
      expect(File(currentPath!).existsSync(), isTrue);
      expect(oldest.existsSync(), isFalse);
      expect(unrelated.existsSync(), isTrue);
    },
  );

  test('uses a unique file name when two launches share a timestamp', () async {
    final temp = await Directory.systemTemp.createTemp(
      'storm_app_log_collision_test_',
    );
    final launchTime = DateTime(2026, 8, 9, 14, 5, 6, 7);
    final first = AppLogPersistence(
      dataDirectoryProvider: () async => temp,
      clock: () => launchTime,
    );
    final second = AppLogPersistence(
      dataDirectoryProvider: () async => temp,
      clock: () => launchTime,
    );
    addTearDown(() async {
      await first.close();
      await second.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    final firstPath = await first.startSession();
    final secondPath = await second.startSession();

    expect(secondPath, isNot(firstPath));
    expect(p.basename(secondPath!), contains('-001.log'));
  });

  test(
    'in-app entries exactly match the complete current launch log',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'storm_app_log_consistency_test_',
      );
      final persistence = AppLogPersistence(
        dataDirectoryProvider: () async => temp,
        clock: () => DateTime(2026, 8, 9, 14, 5, 6, 7),
      );
      final service = AppLogService.forTesting(persistence);
      addTearDown(() async {
        await service.close();
        if (await temp.exists()) await temp.delete(recursive: true);
      });

      for (var index = 0; index < 2001; index++) {
        service.info('[Test] buffered line $index');
      }
      expect(service.entries.value, hasLength(2001));

      await service.startSession();
      service.error(
        '[Test] failure',
        error: StateError('expected error'),
        stackTrace: StackTrace.fromString('test stack line'),
      );

      final fileText = await File(service.currentLogPath!).readAsString();
      expect(fileText, '${service.exportText()}\n');
      expect(service.entries.value.last.level, Level.error);

      service.clear();
      expect(service.exportText(), isEmpty);
      expect(await File(service.currentLogPath!).readAsString(), isEmpty);
    },
  );
}
