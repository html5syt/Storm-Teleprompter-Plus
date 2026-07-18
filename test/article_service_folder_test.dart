import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/backend/article_service.dart';
import 'package:storm_teleprompter_plus/services/system/app_data_directory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('folder move and recursive copy are persisted', () async {
    final temp = await Directory.systemTemp.createTemp(
      'storm_folder_service_test_',
    );
    appDataDirectoryOverride = temp;
    addTearDown(() async {
      appDataDirectoryOverride = null;
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    final service = ArticleService();
    await service.init();
    final root = await service.createFolder(name: '项目');
    final child = await service.createFolder(name: '子目录', parentId: root.id);
    final article = await service.createArticle(
      title: '稿件',
      content: '<p>正文</p>',
      folderId: child.id,
    );
    await service.updateArticle(
      article.id,
      teleprompterSettings: {'fontSize': 72, 'mirrorMode': true},
    );

    final movedToRoot = await service.moveFolder(child.id, null);
    expect(movedToRoot?.parentId, isNull);
    expect(
      (await service.loadFolders())
          .singleWhere((f) => f.id == child.id)
          .parentId,
      isNull,
    );

    await service.moveFolder(child.id, root.id);
    expect(await service.moveFolder(root.id, child.id), isNull);

    final copied = await service.copyFolder(root.id, null);
    expect(copied, isNotNull);
    expect(copied!.folders, hasLength(2));
    final copiedRoot = copied.folders.singleWhere(
      (folder) => folder.name == '项目 - 副本',
    );
    final copiedChild = copied.folders.singleWhere(
      (folder) => folder.name == '子目录',
    );
    expect(copiedRoot.parentId, isNull);
    expect(copiedChild.parentId, copiedRoot.id);
    expect(copied.articles, hasLength(1));
    expect(copied.articles.single.folderId, copiedChild.id);
    expect(copied.articles.single.teleprompterSettings, {
      'fontSize': 72,
      'mirrorMode': true,
    });

    expect(await service.loadFolders(), hasLength(4));
    expect(await service.loadArticles(), hasLength(2));

    expect(await service.deleteFolder(copiedRoot.id), isTrue);
    final remainingCopiedChild = (await service.loadFolders()).singleWhere(
      (folder) => folder.id == copiedChild.id,
    );
    expect(remainingCopiedChild.parentId, isNull);
  });
}
