import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/models/article.dart';
import 'package:storm_teleprompter_plus/models/folder.dart';
import 'package:storm_teleprompter_plus/services/export_service_io.dart';

void main() {
  test('exports selected folders with descendants and hierarchy', () async {
    final temp = await Directory.systemTemp.createTemp('storm_export_test_');
    addTearDown(() => temp.delete(recursive: true));
    final now = DateTime(2026);
    final folders = [
      Folder(id: 'root', name: '项目', createdAt: now),
      Folder(id: 'child', name: '英文稿', parentId: 'root', createdAt: now),
      Folder(id: 'other', name: '未选择', createdAt: now),
    ];
    final articles = [
      Article(
        id: 'a1',
        title: 'Speech',
        content: '<p>Hello</p>',
        folderId: 'child',
        createdAt: now,
        updatedAt: now,
      ),
      Article(
        id: 'a2',
        title: 'Hidden',
        content: '<p>Hidden</p>',
        folderId: 'other',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final result = await ExportService().exportItemsToDirectory(
      targetDirectory: temp.path,
      articles: articles,
      folders: folders,
      selectedIds: {'root'},
    );

    expect(result.count, 1);
    expect(result.folderCount, 2);
    expect(File('${temp.path}/项目/英文稿/Speech.html').existsSync(), isTrue);
    expect(Directory('${temp.path}/未选择').existsSync(), isFalse);
  });

  test('keeps ancestors when exporting a selected nested article', () async {
    final temp = await Directory.systemTemp.createTemp('storm_export_test_');
    addTearDown(() => temp.delete(recursive: true));
    final now = DateTime(2026);
    final folders = [
      Folder(id: 'root', name: '项目', createdAt: now),
      Folder(id: 'child', name: '子目录', parentId: 'root', createdAt: now),
    ];
    final article = Article(
      id: 'article',
      title: '稿件',
      content: '正文',
      folderId: 'child',
      createdAt: now,
      updatedAt: now,
    );

    final result = await ExportService().exportItemsToDirectory(
      targetDirectory: temp.path,
      articles: [article],
      folders: folders,
      selectedIds: {'article'},
    );

    expect(result.count, 1);
    expect(File('${temp.path}/项目/子目录/稿件.html').existsSync(), isTrue);
  });
}
