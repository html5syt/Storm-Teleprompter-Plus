import '../models/script_character.dart';

/// 富文本解析器
///
/// 将 HTML 富文本解析为逐字符数组，保留格式信息。
/// 对应原始项目中 TeleprompterTextLayer 的 HTML 解析逻辑。
class TextParser {
  TextParser._();

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
    double? fontSizeRatio;
    int? backgroundColor;

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
            fontSizeRatio,
            backgroundColor,
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
              fontSizeRatio = null;
              backgroundColor = null;
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
              fontSizeRatio = _extractFontSize(tagContent);
              backgroundColor = _extractBackgroundColor(tagContent);
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
            fontSizeRatio,
            backgroundColor,
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
        fontSizeRatio,
        backgroundColor,
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
    double? fontSizeRatio,
    int? backgroundColor,
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
          fontSizeRatio: fontSizeRatio,
          backgroundColor: backgroundColor,
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

  /// 从标签属性中提取 font-size
  static double? _extractFontSize(String tagContent) {
    final match = RegExp(
      r'font-size:\s*(\d+(?:\.\d+)?)px',
    ).firstMatch(tagContent);
    if (match != null) {
      final px = double.tryParse(match.group(1) ?? '');
      if (px != null) return px / 16; // 转换为相对倍数
    }
    return null;
  }

  /// 从标签属性中提取背景色
  static int? _extractBackgroundColor(String tagContent) {
    // background-color: #XXXXXX
    final match = RegExp(
      r'background(?:-color)?:\s*#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})',
    ).firstMatch(tagContent);
    if (match != null) {
      final hex = match.group(1)!;
      if (hex.length == 6) {
        return int.parse('FF$hex', radix: 16);
      }
      return int.parse(hex, radix: 16);
    }
    // rgba(r, g, b, a) — 暂不支持
    return null;
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
