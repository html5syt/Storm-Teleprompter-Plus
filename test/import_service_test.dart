import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:storm_teleprompter_plus/services/files/import_service_io.dart';

void main() {
  test('imports exported HTML without changing rich text', () async {
    final temp = await Directory.systemTemp.createTemp('storm_html_test_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File(p.join(temp.path, 'speech.html'));
    const html = '<p><strong>Hello</strong> world</p>\n<p>第二行</p>';
    await file.writeAsString(html);

    final result = await ImportService().importFile(file.path);

    expect(result, isNotNull);
    expect(result!.title, 'speech');
    expect(result.content, html);
  });

  test('imports multiple folders while preserving their hierarchy', () async {
    final temp = await Directory.systemTemp.createTemp('storm_import_test_');
    addTearDown(() => temp.delete(recursive: true));

    final firstRoot = Directory(p.join(temp.path, 'first', 'Project'));
    final secondRoot = Directory(p.join(temp.path, 'second', 'Project'));
    await Directory(
      p.join(firstRoot.path, 'sub', 'empty'),
    ).create(recursive: true);
    await secondRoot.create(recursive: true);
    await File(
      p.join(firstRoot.path, 'sub', 'speech.txt'),
    ).writeAsString('Line one\nLine two');
    await File(p.join(firstRoot.path, 'cover.png')).writeAsBytes([1, 2, 3]);
    await File(p.join(secondRoot.path, 'notes.txt')).writeAsString('Notes');
    final directFile = File(p.join(temp.path, 'direct.txt'));
    await directFile.writeAsString('Direct');

    final result = await ImportService().importPaths([
      firstRoot.path,
      secondRoot.path,
      directFile.path,
    ]);

    final folderPaths = result.folders
        .map((folder) => folder.relativePath.join('/'))
        .toSet();
    expect(
      folderPaths,
      containsAll({
        'Project',
        'Project/sub',
        'Project/sub/empty',
        'Project (2)',
      }),
    );

    final filesByTitle = {
      for (final file in result.files) file.article.title: file,
    };
    expect(filesByTitle.keys, containsAll(['speech', 'notes', 'direct']));
    expect(filesByTitle['speech']!.relativeFolderPath, ['Project', 'sub']);
    expect(filesByTitle['notes']!.relativeFolderPath, ['Project (2)']);
    expect(filesByTitle['direct']!.relativeFolderPath, isEmpty);
    expect(
      filesByTitle['speech']!.article.content,
      contains('<p>Line two</p>'),
    );
    expect(result.skippedCount, 1);
    expect(result.failures, isEmpty);
  });
}
