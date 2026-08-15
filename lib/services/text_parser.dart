import '../models/script_character.dart';

class TextParser {
  TextParser._();

  static final RegExp _invisibleCharacters = RegExp(
    r'[\s\u00A0\u200B-\u200F\u202A-\u202E\u2060\u2066-\u2069\uFEFF]',
  );

  static int visibleCharacterCount(String text) {
    return text.replaceAll(_invisibleCharacters, '').runes.length;
  }

  static List<ScriptLine> parse(String htmlContent) {
    if (htmlContent.trim().isEmpty) return [];

    final lines = <ScriptLine>[];
    final buffer = StringBuffer();
    int lineIndex = 0;
    int rawIndex = 0;

    bool bold = false;
    bool italic = false;
    bool underline = false;
    bool strikeThrough = false;
    double? fontSizePx;
    int? backgroundColor;
    int? textColor;

    int i = 0;
    while (i < htmlContent.length) {
      final char = htmlContent[i];

      if (char == '<') {
        if (buffer.isNotEmpty) {
          _flushBuffer(
            buffer,
            lines,
            lineIndex,
            rawIndex,
            bold,
            italic,
            underline,
            strikeThrough,
            fontSizePx,
            backgroundColor,
            textColor,
          );
          rawIndex += buffer.length;
          buffer.clear();
        }

        final tagEnd = htmlContent.indexOf('>', i);
        if (tagEnd == -1) {
          buffer.write(char);
          rawIndex++;
          i++;
          continue;
        }

        final tag = htmlContent.substring(i, tagEnd + 1);
        i = tagEnd + 1;

        if (tag.endsWith('/>') || tag == '<br/>' || tag == '<br>') {
          if (lines.isEmpty || lines.last.characters.isNotEmpty) {
            lines.add(ScriptLine(characters: [], lineIndex: lineIndex));
            lineIndex++;
          }
          continue;
        }

        final isClosing = tag.startsWith('</');
        final tagContent = isClosing
            ? tag.substring(2, tag.length - 1).trim().toLowerCase()
            : tag.substring(1, tag.length - 1).trim().toLowerCase();

        final tagName = tagContent.split(RegExp(r'\s+')).first;

        if (_isBlockElement(tagName)) {
          if (!isClosing) {
            if (lines.isEmpty || lines.last.characters.isNotEmpty) {
              lines.add(ScriptLine(characters: [], lineIndex: lineIndex));
              lineIndex++;
            }
          }
          continue;
        }

        if (isClosing) {
          switch (tagName) {
            case 'b':
            case 'strong':
              bold = false;
              break;
            case 'i':
            case 'em':
              italic = false;
              break;
            case 'u':
              underline = false;
              break;
            case 's':
            case 'strike':
            case 'del':
              strikeThrough = false;
              break;
            case 'span':
              fontSizePx = null;
              backgroundColor = null;
              textColor = null;
              break;
          }
        } else {
          switch (tagName) {
            case 'b':
            case 'strong':
              bold = true;
              break;
            case 'i':
            case 'em':
              italic = true;
              break;
            case 'u':
              underline = true;
              break;
            case 's':
            case 'strike':
            case 'del':
              strikeThrough = true;
              break;
            case 'span':
              fontSizePx = _extractFontSizePx(tagContent);
              backgroundColor = _extractBackgroundColor(tagContent);
              textColor = _extractTextColor(tagContent);
              break;
          }
        }
        continue;
      }

      if (char == '\n') {
        if (buffer.isNotEmpty) {
          _flushBuffer(
            buffer,
            lines,
            lineIndex,
            rawIndex,
            bold,
            italic,
            underline,
            strikeThrough,
            fontSizePx,
            backgroundColor,
            textColor,
          );
          rawIndex += buffer.length;
          buffer.clear();
        }
        if (lines.isEmpty || lines.last.characters.isNotEmpty) {
          lines.add(ScriptLine(characters: [], lineIndex: lineIndex));
          lineIndex++;
        }
      } else {
        buffer.write(char);
      }
      i++;
    }

    if (buffer.isNotEmpty) {
      _flushBuffer(
        buffer,
        lines,
        lineIndex,
        rawIndex,
        bold,
        italic,
        underline,
        strikeThrough,
        fontSizePx,
        backgroundColor,
        textColor,
      );
    }

    if (lines.isEmpty) {
      lines.add(const ScriptLine(characters: [], lineIndex: 0));
    }

    return lines;
  }

  static void _flushBuffer(
    StringBuffer buffer,
    List<ScriptLine> lines,
    int lineIndex,
    int startRawIndex,
    bool bold,
    bool italic,
    bool underline,
    bool strikeThrough,
    double? fontSizePx,
    int? backgroundColor,
    int? textColor,
  ) {
    if (lines.isEmpty) {
      lines.add(ScriptLine(characters: [], lineIndex: lineIndex));
    }

    final text = buffer.toString();
    for (int i = 0; i < text.length; i++) {
      lines.last.characters.add(
        ScriptCharacter(
          char: text[i],
          rawIndex: startRawIndex + i,
          bold: bold,
          italic: italic,
          underline: underline,
          strikeThrough: strikeThrough,
          fontSizePx: fontSizePx,
          backgroundColor: backgroundColor,
          textColor: textColor,
        ),
      );
    }
  }

  static bool _isBlockElement(String tag) {
    return [
      'p',
      'div',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'blockquote',
      'li',
    ].contains(tag);
  }

  static double? _extractFontSizePx(String tagContent) {
    final value = RegExp(
      r'''font-size:\s*([^;"']+)''',
      caseSensitive: false,
    ).firstMatch(tagContent)?.group(1)?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;

    switch (value) {
      case 'small':
        return 13;
      case 'normal':
        return 16;
      case 'large':
        return 24;
      case 'huge':
        return 32;
    }

    final numberMatch = RegExp(
      r'^(\d+(?:\.\d+)?)(px|pt|em|rem)?$',
      caseSensitive: false,
    ).firstMatch(value);
    if (numberMatch == null) return null;

    final number = double.tryParse(numberMatch.group(1) ?? '');
    if (number == null || number <= 0) return null;
    final unit = numberMatch.group(2);
    if (unit == 'pt') return number * 96 / 72;
    if (unit == 'em' || unit == 'rem') return number * 16;
    return number;
  }

  static int? _extractBackgroundColor(String tagContent) {
    final value = RegExp(
      r'''background(?:-color)?:\s*([^;"']+)''',
      caseSensitive: false,
    ).firstMatch(tagContent)?.group(1);
    return value == null ? null : _parseCssColor(value);
  }

  static int? _extractTextColor(String tagContent) {
    final value = RegExp(
      r'''(?:^|[;"\s])color:\s*([^;"']+)''',
      caseSensitive: false,
    ).firstMatch(tagContent)?.group(1);
    return value == null ? null : _parseCssColor(value);
  }

  static int? _parseCssColor(String value) {
    final color = value.trim();
    final hexMatch = RegExp(
      r'^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
    ).firstMatch(color);
    if (hexMatch != null) {
      final hex = hexMatch.group(1)!;
      if (hex.length == 6) {
        return int.parse('FF$hex', radix: 16);
      }
      return int.parse(hex, radix: 16);
    }

    final rgbaMatch = RegExp(
      r'^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})(?:\s*,\s*([0-9.]+)\s*)?\)$',
      caseSensitive: false,
    ).firstMatch(color);
    if (rgbaMatch == null) return null;

    final r = int.parse(rgbaMatch.group(1)!).clamp(0, 255).toInt();
    final g = int.parse(rgbaMatch.group(2)!).clamp(0, 255).toInt();
    final b = int.parse(rgbaMatch.group(3)!).clamp(0, 255).toInt();
    final alphaText = rgbaMatch.group(4);
    final a = alphaText == null
        ? 255
        : (double.parse(alphaText).clamp(0.0, 1.0) * 255).round();
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  static String decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&');
  }

  static String encodeHtmlEntities(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String normalizeQuotePairs(String text) {
    final buffer = StringBuffer();
    var doubleOpen = true;
    var singleOpen = true;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (_isDoubleQuote(char)) {
        buffer.write(doubleOpen ? '“' : '”');
        doubleOpen = !doubleOpen;
      } else if (_isSingleQuote(char)) {
        if (_isAsciiApostrophe(text, i)) {
          buffer.write(char);
        } else {
          buffer.write(singleOpen ? '‘' : '’');
          singleOpen = !singleOpen;
        }
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  static bool _isDoubleQuote(String char) =>
      char == '"' || char == '“' || char == '”';

  static bool _isSingleQuote(String char) =>
      char == "'" || char == '‘' || char == '’';

  static bool _isAsciiApostrophe(String text, int index) {
    if (text[index] != "'") return false;
    if (index == 0 || index >= text.length - 1) return false;
    return RegExp(r'[A-Za-z0-9]').hasMatch(text[index - 1]) &&
        RegExp(r'[A-Za-z0-9]').hasMatch(text[index + 1]);
  }

  static List<ScriptLine> parsePlainText(String text) {
    if (text.trim().isEmpty) return [];

    final lines = <ScriptLine>[];
    final textLines = text.split('\n');

    for (int lineIdx = 0; lineIdx < textLines.length; lineIdx++) {
      final lineText = textLines[lineIdx];
      final characters = <ScriptCharacter>[];

      int rawOffset = 0;
      for (int prev = 0; prev < lineIdx; prev++) {
        rawOffset += textLines[prev].length + 1; 
      }

      for (int charIdx = 0; charIdx < lineText.length; charIdx++) {
        characters.add(
          ScriptCharacter(
            char: lineText[charIdx],
            rawIndex: rawOffset + charIdx,
          ),
        );
      }

      lines.add(ScriptLine(characters: characters, lineIndex: lineIdx));
    }

    return lines;
  }

  static bool isHtml(String content) {
    return content.contains(RegExp(r'<[a-zA-Z][^>]*>'));
  }
}
