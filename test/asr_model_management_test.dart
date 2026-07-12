import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/services/app_data_directory.dart';
import 'package:storm_teleprompter_plus/services/asr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'imported models ignore archive symlinks and can be listed and deleted',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'storm_asr_model_test_',
      );
      final archiveFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}fixture.tar.bz2',
      );
      final modelId =
          'test-imported-model-${DateTime.now().microsecondsSinceEpoch}';
      appDataDirectoryOverride = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}app_data',
      );
      final service = AsrService.instance;

      addTearDown(() async {
        await service.deleteModel(modelId);
        appDataDirectoryOverride = null;
        if (await temporaryDirectory.exists()) {
          await temporaryDirectory.delete(recursive: true);
        }
      });

      final archive = Archive()
        ..addFile(ArchiveFile.string('fixture/tokens.txt', 'a 0'))
        ..addFile(ArchiveFile('fixture/encoder.onnx', 1, [0]))
        ..addFile(ArchiveFile('fixture/decoder.onnx', 1, [0]))
        ..addFile(ArchiveFile.symlink('fixture/test_wavs/*', '0.wav'));
      final tarBytes = TarEncoder().encodeBytes(archive);
      await archiveFile.writeAsBytes(BZip2Encoder().encodeBytes(tarBytes));

      expect(
        await service.importModelArchive(archiveFile.path, modelId: modelId),
        modelId,
      );
      expect(await service.isModelDownloaded(modelId), isTrue);

      final importedModel = (await service.listAvailableModels()).singleWhere(
        (model) => model.id == modelId,
      );
      expect(importedModel.isImported, isTrue);
      expect(importedModel.name, 'fixture');

      await service.deleteModel(modelId);
      expect(await service.isModelDownloaded(modelId), isFalse);
      expect(
        (await service.listAvailableModels()).any(
          (model) => model.id == modelId,
        ),
        isFalse,
      );
    },
  );
}
