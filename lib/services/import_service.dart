import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class ImportedArticleDraft {
  final String title;
  final String content;

  const ImportedArticleDraft({required this.title, required this.content});
}

class ImportService {
  Future<ImportedArticleDraft?> importFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;

    final lower = path.toLowerCase();
    if (lower.endsWith('.txt')) return _importTxt(file);
    if (lower.endsWith('.docx')) return _importDocx(file);
    return null;
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
