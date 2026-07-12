import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'import_batch.dart';

/// 原生平台稿件导入服务。
///
/// 单文件解析统一生成 HTML 正文；批量导入在此基础上扫描目录并记录相对路径，
/// 由页面层负责在后端中创建对应的文件夹和稿件。
class ImportService {
  static const supportedExtensions = {'.txt', '.docx', '.html', '.htm'};

  Future<ImportedArticleDraft?> importFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;

    final lower = path.toLowerCase();
    if (lower.endsWith('.txt')) return _importTxt(file);
    if (lower.endsWith('.docx')) return _importDocx(file);
    if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      return _importHtml(file);
    }
    return null;
  }

  Future<ImportBatchDraft> importPaths(List<String> paths) async {
    final folders = <ImportedFolderDraft>[];
    final files = <ImportedFileDraft>[];
    final failures = <String>[];
    var skippedCount = 0;
    final seenFolders = <String>{};
    final seenSources = <String>{};
    final usedRootNames = <String>{};

    for (final sourcePath in paths) {
      final normalized = p.normalize(sourcePath);
      if (!seenSources.add(_pathKey(normalized))) continue;

      try {
        final type = await FileSystemEntity.type(
          normalized,
          followLinks: false,
        );
        if (type == FileSystemEntityType.directory) {
          final rootName = _uniqueRootName(
            p.basename(normalized),
            usedRootNames,
          );
          skippedCount += await _importDirectory(
            Directory(normalized),
            rootName: rootName,
            folders: folders,
            files: files,
            failures: failures,
            seenFolders: seenFolders,
          );
        } else if (type == FileSystemEntityType.file) {
          final supported = await _importFileIntoBatch(
            normalized,
            const [],
            files: files,
            failures: failures,
          );
          if (!supported) skippedCount++;
        } else {
          failures.add('${p.basename(normalized)}: 路径不存在或无法读取');
        }
      } catch (error) {
        failures.add('${p.basename(normalized)}: 无法读取（$error）');
      }
    }

    return ImportBatchDraft(
      folders: folders,
      files: files,
      failures: failures,
      skippedCount: skippedCount,
    );
  }

  Future<int> _importDirectory(
    Directory root, {
    required String rootName,
    required List<ImportedFolderDraft> folders,
    required List<ImportedFileDraft> files,
    required List<String> failures,
    required Set<String> seenFolders,
  }) async {
    final rootParts = [rootName];
    _addFolder(rootParts, folders, seenFolders);
    var skippedCount = 0;

    try {
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        final relative = p.relative(entity.path, from: root.path);
        final relativeParts = p.split(relative);
        if (entity is Directory) {
          _addFolder([...rootParts, ...relativeParts], folders, seenFolders);
          continue;
        }
        if (entity is! File) continue;
        final supported = await _importFileIntoBatch(
          entity.path,
          [...rootParts, ...relativeParts.take(relativeParts.length - 1)],
          files: files,
          failures: failures,
        );
        if (!supported) skippedCount++;
      }
    } catch (error) {
      failures.add('$rootName: 无法读取文件夹（$error）');
    }
    return skippedCount;
  }

  void _addFolder(
    List<String> parts,
    List<ImportedFolderDraft> folders,
    Set<String> seenFolders,
  ) {
    final key = parts.map(_pathKey).join('/');
    if (seenFolders.add(key)) {
      folders.add(ImportedFolderDraft(List.unmodifiable(parts)));
    }
  }

  Future<bool> _importFileIntoBatch(
    String path,
    List<String> relativeFolderPath, {
    required List<ImportedFileDraft> files,
    required List<String> failures,
  }) async {
    if (!supportedExtensions.contains(p.extension(path).toLowerCase())) {
      return false;
    }
    try {
      final article = await importFile(path);
      if (article == null) {
        failures.add('${p.basename(path)}: 不支持的文件格式');
        return true;
      }
      files.add(
        ImportedFileDraft(
          sourcePath: path,
          relativeFolderPath: List.unmodifiable(relativeFolderPath),
          article: article,
        ),
      );
    } catch (error) {
      failures.add('${p.basename(path)}: $error');
    }
    return true;
  }

  String _pathKey(String value) =>
      Platform.isWindows ? value.toLowerCase() : value;

  String _uniqueRootName(String requested, Set<String> usedNames) {
    var candidate = requested;
    var suffix = 2;
    while (!usedNames.add(_pathKey(candidate))) {
      candidate = '$requested ($suffix)';
      suffix++;
    }
    return candidate;
  }

  Future<ImportedArticleDraft> _importTxt(File file) async {
    final bytes = await file.readAsBytes();
    final text = utf8.decode(bytes, allowMalformed: true);
    return ImportedArticleDraft(
      title: _titleFromPath(file.path),
      content: _plainTextToParagraphHtml(text),
    );
  }

  Future<ImportedArticleDraft> _importDocx(File file) async {
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final documentFile = archive.findFile('word/document.xml');
    if (documentFile == null) {
      throw const FormatException('docx 缺少 word/document.xml');
    }

    final xmlText = utf8.decode(documentFile.content, allowMalformed: true);
    final document = XmlDocument.parse(xmlText);
    final body = _firstElement(document, 'body');
    final paragraphs = body == null
        ? <String>[]
        : _children(body, 'p').map(_paragraphToHtml).toList();

    return ImportedArticleDraft(
      title: _titleFromPath(file.path),
      content: paragraphs.where((p) => p.trim().isNotEmpty).join('\n'),
    );
  }

  Future<ImportedArticleDraft> _importHtml(File file) async {
    // 应用导出的稿件本身就是编辑器可读取的 HTML，无需再次转换样式。
    final content = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    return ImportedArticleDraft(
      title: _titleFromPath(file.path),
      content: content,
    );
  }

  String _paragraphToHtml(XmlElement paragraph) {
    final buffer = StringBuffer();
    for (final run in _descendants(paragraph, 'r')) {
      final style = _readRunStyle(run);
      final text = _readRunText(run);
      if (text.isEmpty) continue;
      buffer.write(_wrapRun(text, style));
    }
    return '<p>${buffer.toString()}</p>';
  }

  _DocxRunStyle _readRunStyle(XmlElement run) {
    final properties = _child(run, 'rPr');
    if (properties == null) return const _DocxRunStyle();

    final sizeValue =
        _child(properties, 'sz')?.getAttribute('w:val') ??
        _child(properties, 'sz')?.getAttribute('val');
    final halfPoints = int.tryParse(sizeValue ?? '');
    final fontSizePx = halfPoints == null
        ? null
        : ((halfPoints / 2) * 96 / 72).round().clamp(8, 96);

    final highlight =
        _child(properties, 'highlight')?.getAttribute('w:val') ??
        _child(properties, 'highlight')?.getAttribute('val');
    final shading =
        _child(properties, 'shd')?.getAttribute('w:fill') ??
        _child(properties, 'shd')?.getAttribute('fill');

    return _DocxRunStyle(
      bold: _child(properties, 'b') != null,
      italic: _child(properties, 'i') != null,
      underline: _child(properties, 'u') != null,
      strike:
          _child(properties, 'strike') != null ||
          _child(properties, 'dstrike') != null,
      fontSizePx: fontSizePx,
      backgroundHex: _backgroundHex(highlight, shading),
    );
  }

  String _readRunText(XmlElement run) {
    final buffer = StringBuffer();
    for (final node in run.children.whereType<XmlElement>()) {
      switch (node.name.local) {
        case 't':
          buffer.write(node.innerText);
          break;
        case 'tab':
          buffer.write('\t');
          break;
        case 'br':
          buffer.write('<br>');
          break;
      }
    }
    return buffer.toString();
  }

  String _wrapRun(String text, _DocxRunStyle style) {
    var result = const HtmlEscape(HtmlEscapeMode.element).convert(text);
    result = result.replaceAll('&lt;br&gt;', '<br>');

    if (style.bold) result = '<b>$result</b>';
    if (style.italic) result = '<i>$result</i>';
    if (style.underline) result = '<u>$result</u>';
    if (style.strike) result = '<s>$result</s>';

    final styles = <String>[];
    if (style.fontSizePx != null) {
      styles.add('font-size: ${style.fontSizePx}px');
    }
    if (style.backgroundHex != null) {
      styles.add('background-color: #${style.backgroundHex}');
    }
    if (styles.isNotEmpty) {
      result = '<span style="${styles.join('; ')}">$result</span>';
    }
    return result;
  }

  String _plainTextToParagraphHtml(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map(
          (line) =>
              '<p>${const HtmlEscape(HtmlEscapeMode.element).convert(line)}</p>',
        )
        .join('\n');
  }

  String _titleFromPath(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    return name.replaceFirst(RegExp(r'\.[^.]+$'), '').trim();
  }

  String? _backgroundHex(String? highlight, String? shading) {
    final fill = shading?.trim();
    if (fill != null &&
        fill.isNotEmpty &&
        fill.toLowerCase() != 'auto' &&
        RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(fill)) {
      return fill.toUpperCase();
    }

    switch (highlight?.toLowerCase()) {
      case 'yellow':
        return 'FFF59D';
      case 'green':
        return 'A5D6A7';
      case 'cyan':
        return '80DEEA';
      case 'magenta':
        return 'F48FB1';
      case 'blue':
        return '90CAF9';
      case 'red':
        return 'EF9A9A';
      case 'darkyellow':
        return 'FBC02D';
      case 'darkgreen':
        return '388E3C';
      case 'darkcyan':
        return '0097A7';
      case 'darkmagenta':
        return 'C2185B';
      case 'darkblue':
        return '1976D2';
      case 'darkred':
        return 'D32F2F';
    }
    return null;
  }

  XmlElement? _firstElement(XmlNode node, String localName) {
    return node.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == localName)
        .firstOrNull;
  }

  XmlElement? _child(XmlElement node, String localName) {
    return node.children
        .whereType<XmlElement>()
        .where((e) => e.name.local == localName)
        .firstOrNull;
  }

  Iterable<XmlElement> _children(XmlElement node, String localName) {
    return node.children.whereType<XmlElement>().where(
      (e) => e.name.local == localName,
    );
  }

  Iterable<XmlElement> _descendants(XmlElement node, String localName) {
    return node.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == localName,
    );
  }
}

class _DocxRunStyle {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final int? fontSizePx;
  final String? backgroundHex;

  const _DocxRunStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.fontSizePx,
    this.backgroundHex,
  });
}
