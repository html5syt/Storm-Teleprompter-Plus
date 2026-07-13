import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../../models/article.dart';
import '../../models/folder.dart';

class ExportResult {
  final int count;
  final int folderCount;
  final String? message;

  const ExportResult({required this.count, this.folderCount = 0, this.message});
}

class ExportService {
  Future<ExportResult> exportArticles(List<Article> articles) {
    return exportItems(
      articles: articles,
      folders: const [],
      selectedIds: articles.map((article) => article.id).toSet(),
    );
  }

  Future<ExportResult> exportItems({
    required List<Article> articles,
    required List<Folder> folders,
    required Set<String> selectedIds,
  }) async {
    if (selectedIds.isEmpty) {
      return const ExportResult(count: 0, message: '没有可导出的项目');
    }
    final targetDirectory = await getDirectoryPath(
      confirmButtonText: '导出到此文件夹',
    );
    if (targetDirectory == null || targetDirectory.isEmpty) {
      return const ExportResult(count: 0);
    }
    return exportItemsToDirectory(
      targetDirectory: targetDirectory,
      articles: articles,
      folders: folders,
      selectedIds: selectedIds,
    );
  }

  Future<ExportResult> exportItemsToDirectory({
    required String targetDirectory,
    required List<Article> articles,
    required List<Folder> folders,
    required Set<String> selectedIds,
  }) async {
    final folderById = {for (final folder in folders) folder.id: folder};
    final selectedFolderIds = folders
        .where((folder) => selectedIds.contains(folder.id))
        .map((folder) => folder.id)
        .toSet();
    final includedFolderIds = <String>{};

    void includeDescendants(String folderId) {
      if (!includedFolderIds.add(folderId)) return;
      for (final child in folders.where(
        (folder) => folder.parentId == folderId,
      )) {
        includeDescendants(child.id);
      }
    }

    for (final folderId in selectedFolderIds) {
      includeDescendants(folderId);
    }

    final includedArticles = articles.where((article) {
      return selectedIds.contains(article.id) ||
          (article.folderId != null &&
              includedFolderIds.contains(article.folderId));
    }).toList();

    void includeAncestors(String? folderId) {
      var currentId = folderId;
      while (currentId != null &&
          folderById.containsKey(currentId) &&
          includedFolderIds.add(currentId)) {
        currentId = folderById[currentId]?.parentId;
      }
    }

    for (final folderId in selectedFolderIds.toList()) {
      includeAncestors(folderById[folderId]?.parentId);
    }
    for (final article in includedArticles) {
      includeAncestors(article.folderId);
    }

    if (includedArticles.isEmpty && includedFolderIds.isEmpty) {
      return const ExportResult(count: 0, message: '没有可导出的项目');
    }

    final root = Directory(targetDirectory);
    if (!await root.exists()) await root.create(recursive: true);
    var exportedArticles = 0;
    var exportedFolders = 0;

    Future<void> exportArticle(Article article, Directory directory) async {
      final file = await _uniqueFile(directory, article.title, '.html');
      await file.writeAsString(article.content, flush: true);
      exportedArticles++;
    }

    Future<void> exportFolder(Folder folder, Directory parent) async {
      final directory = await _uniqueDirectory(parent, folder.name);
      exportedFolders++;
      final childFolders =
          folders
              .where(
                (child) =>
                    child.parentId == folder.id &&
                    includedFolderIds.contains(child.id),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      for (final child in childFolders) {
        await exportFolder(child, directory);
      }
      final childArticles =
          includedArticles
              .where((article) => article.folderId == folder.id)
              .toList()
            ..sort((a, b) => a.title.compareTo(b.title));
      for (final article in childArticles) {
        await exportArticle(article, directory);
      }
    }

    final rootFolders =
        folders
            .where(
              (folder) =>
                  includedFolderIds.contains(folder.id) &&
                  (folder.parentId == null ||
                      !includedFolderIds.contains(folder.parentId)),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    for (final folder in rootFolders) {
      await exportFolder(folder, root);
    }
    final rootArticles =
        includedArticles
            .where(
              (article) =>
                  article.folderId == null ||
                  !includedFolderIds.contains(article.folderId),
            )
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));
    for (final article in rootArticles) {
      await exportArticle(article, root);
    }

    return ExportResult(count: exportedArticles, folderCount: exportedFolders);
  }

  Future<Directory> _uniqueDirectory(Directory parent, String name) async {
    final baseName = _safeFileName(name, fallback: '未命名文件夹');
    var candidate = Directory(
      '${parent.path}${Platform.pathSeparator}$baseName',
    );
    var suffix = 2;
    while (await candidate.exists()) {
      candidate = Directory(
        '${parent.path}${Platform.pathSeparator}$baseName ($suffix)',
      );
      suffix++;
    }
    await candidate.create(recursive: true);
    return candidate;
  }

  Future<File> _uniqueFile(
    Directory directory,
    String name,
    String extension,
  ) async {
    final baseName = _safeFileName(name, fallback: '未命名稿件');
    var candidate = File(
      '${directory.path}${Platform.pathSeparator}$baseName$extension',
    );
    var suffix = 2;
    while (await candidate.exists()) {
      candidate = File(
        '${directory.path}${Platform.pathSeparator}$baseName ($suffix)$extension',
      );
      suffix++;
    }
    return candidate;
  }

  String _safeFileName(String name, {required String fallback}) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }
}
