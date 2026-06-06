import 'package:flutter/material.dart';

class ParsedLine {
  const ParsedLine({
    required this.text,
    required this.index,
    required this.styles,
  });

  final String text;
  final int index;
  final TextStyle styles;
}

class ParsedScript {
  const ParsedScript({required this.lines, required this.plainText});

  final List<ParsedLine> lines;
  final String plainText;
}

ParsedScript parseScript(String source, {TextStyle? baseStyle}) {
  final normalized = source.replaceAll('\r\n', '\n').trimRight();
  final lines = <ParsedLine>[];
  final plain = StringBuffer();
  var lineBuffer = StringBuffer();
  var lineIndex = 0;
  final styleStack = <TextStyle>[baseStyle ?? const TextStyle()];

  void flushLine() {
    final text = lineBuffer.toString();
    lines.add(
      ParsedLine(text: text, index: lineIndex, styles: styleStack.last),
    );
    plain.writeln(text);
    lineBuffer = StringBuffer();
    lineIndex += 1;
  }

  final tagPattern = RegExp(r'<[^>]+>|[^<]+');
  for (final match in tagPattern.allMatches(normalized)) {
    final token = match.group(0) ?? '';
    if (token.isEmpty) {
      continue;
    }

    if (token.startsWith('<')) {
      final lower = token.toLowerCase();
      if (lower.startsWith('<br')) {
        flushLine();
        continue;
      }
      if (_isBlockStart(lower)) {
        if (lineBuffer.isNotEmpty) {
          flushLine();
        }
        continue;
      }
      if (_isBlockEnd(lower)) {
        if (lineBuffer.isNotEmpty) {
          flushLine();
        }
        continue;
      }
      if (lower.startsWith('<strong') || lower.startsWith('<b')) {
        styleStack.add(styleStack.last.copyWith(fontWeight: FontWeight.w700));
      } else if (lower.startsWith('</strong') || lower.startsWith('</b')) {
        if (styleStack.length > 1) {
          styleStack.removeLast();
        }
      } else if (lower.startsWith('<em') || lower.startsWith('<i')) {
        styleStack.add(styleStack.last.copyWith(fontStyle: FontStyle.italic));
      } else if (lower.startsWith('</em') || lower.startsWith('</i')) {
        if (styleStack.length > 1) {
          styleStack.removeLast();
        }
      } else if (lower.startsWith('<u')) {
        styleStack.add(
          styleStack.last.copyWith(decoration: TextDecoration.underline),
        );
      } else if (lower.startsWith('</u')) {
        if (styleStack.length > 1) {
          styleStack.removeLast();
        }
      } else if (lower.startsWith('<s') ||
          lower.startsWith('<strike') ||
          lower.startsWith('<del')) {
        styleStack.add(
          styleStack.last.copyWith(decoration: TextDecoration.lineThrough),
        );
      } else if (lower.startsWith('</s') ||
          lower.startsWith('</strike') ||
          lower.startsWith('</del')) {
        if (styleStack.length > 1) {
          styleStack.removeLast();
        }
      }
      continue;
    }

    lineBuffer.write(token);
  }

  if (lineBuffer.isNotEmpty || lines.isEmpty) {
    flushLine();
  }

  return ParsedScript(lines: lines, plainText: plain.toString().trimRight());
}

bool _isBlockStart(String token) {
  return token.startsWith('<p') ||
      token.startsWith('<div') ||
      token.startsWith('<li') ||
      token.startsWith('<blockquote') ||
      token.startsWith('<h1') ||
      token.startsWith('<h2') ||
      token.startsWith('<h3') ||
      token.startsWith('<h4') ||
      token.startsWith('<h5') ||
      token.startsWith('<h6');
}

bool _isBlockEnd(String token) {
  return token.startsWith('</p') ||
      token.startsWith('</div') ||
      token.startsWith('</li') ||
      token.startsWith('</blockquote') ||
      token.startsWith('</h1') ||
      token.startsWith('</h2') ||
      token.startsWith('</h3') ||
      token.startsWith('</h4') ||
      token.startsWith('</h5') ||
      token.startsWith('</h6');
}
