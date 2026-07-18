import '../models/script_character.dart';

/// 富文本解析器
///
/// 将 HTML 富文本解析为逐字符数组，保留格式信息。
/// 对应原始项目中 TeleprompterTextLayer 的 HTML 解析逻辑。
class TextParser {
  TextParser._();

  static final RegExp _invisibleCharacters = RegExp(
    r'[\s\u00A0\u200B-\u200F\u202A-\u202E\u2060\u2066-\u2069\uFEFF]',
  );

  /// 统计去除空白、零宽字符和双向文本控制符后的可见字符数。
  static int visibleCharacterCount(String text) {
    return text.replaceAll(_invisibleCharacters, '').runes.length;
  }

  /// 解析 HTML 内容为字符行列表
  ///
  /// 支持的格式标签：
  /// - 粗体: `<b>`, `<strong>`
  /// - 斜体: `<i>`, `<em>`
  /// - 下划线: `<u>`
  /// - 删除线: `<s>`, `<strike>`, `<del>`
  /// - 字体大小: `style="font-size: XXpx"`
  /// - 背景色: `style="background-color: #XXXXXX"` 或 `style="background: #XXXXXX"`
  /// - 段落: `<p>`, `<div>`, `<h1>`~`<h6>` 作为分行依据
  static List<ScriptLine> parse(String htmlContent) {
    if (htmlContent.trim().isEmpty) return [];

    final lines = <ScriptLine>[];
    final buffer = StringBuffer();
    int lineIndex = 0;
    int rawIndex = 0;

    // 格式栈
    bool bold = false;
    bool italic = false;
    bool underline = false;
    bool strikeThrough = false;
    double? fontSizePx;
    int? backgroundColor;
    int? textColor;

    // 简化的 HTML 解析状态机
    int i = 0;
    while (i < htmlContent.length) {
      final char = htmlContent[i];

      if (char == '<') {
        // 将缓冲区中的文字添加到当前行
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

        // 找到标签结束
        final tagEnd = htmlContent.indexOf('>', i);
        if (tagEnd == -1) {
          // 不完整的标签，当作普通文字
          buffer.write(char);
          rawIndex++;
          i++;
          continue;
        }

        final tag = htmlContent.substring(i, tagEnd + 1);
        i = tagEnd + 1;

        // 判断是否为自闭合标签
        if (tag.endsWith('/>') || tag == '<br/>' || tag == '<br>') {
          // 换行
          if (lines.isEmpty || lines.last.characters.isNotEmpty) {
            lines.add(ScriptLine(characters: [], lineIndex: lineIndex));
            lineIndex++;
          }
          continue;
        }

        // 处理标签
        final isClosing = tag.startsWith('</');
        final tagContent = isClosing
            ? tag.substring(2, tag.length - 1).trim().toLowerCase()
            : tag.substring(1, tag.length - 1).trim().toLowerCase();

        // 提取标签名（忽略属性）
        final tagName = tagContent.split(RegExp(r'\s+')).first;

        // 块级元素处理
        if (_isBlockElement(tagName)) {
          if (!isClosing) {
            // 开始新行
            if (lines.isEmpty || lines.last.characters.isNotEmpty) {
              lines.add(ScriptLine(characters: [], lineIndex: lineIndex));
              lineIndex++;
            }
          }
          continue;
        }

        // 行内格式标签
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

      // 普通字符
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

    // 处理剩余缓冲区
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

    // 确保至少有一行
    if (lines.isEmpty) {
      lines.add(const ScriptLine(characters: [], lineIndex: 0));
    }

    return lines;
  }

  /// 将缓冲区内容作为字符追加到当前行
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

  /// 判断是否为块级元素
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

  /// 从标签属性中提取 font-size，单位统一为 px。
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

  /// 从标签属性中提取背景色
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

  /// 将纯文本解析为字符行列表（不含格式）
  static List<ScriptLine> parsePlainText(String text) {
    if (text.trim().isEmpty) return [];

    final lines = <ScriptLine>[];
    final textLines = text.split('\n');

    for (int lineIdx = 0; lineIdx < textLines.length; lineIdx++) {
      final lineText = textLines[lineIdx];
      final characters = <ScriptCharacter>[];

      // 计算之前的字符总数作为起始 rawIndex
      int rawOffset = 0;
      for (int prev = 0; prev < lineIdx; prev++) {
        rawOffset += textLines[prev].length + 1; // +1 for \n
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

  /// 判断内容是否为 HTML
  static bool isHtml(String content) {
    return content.contains(RegExp(r'<[a-zA-Z][^>]*>'));
  }
}
