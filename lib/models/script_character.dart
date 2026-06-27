/// 带格式信息的单个字符
///
/// 用于文本渲染层，每个字符携带独立的格式属性。
class ScriptCharacter {
  final String char;
  final int rawIndex;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikeThrough;
  final double? fontSizeRatio; // 相对基字号的倍数
  final double? fontSizePx; // 富文本指定的绝对字号
  final int? backgroundColor; // 背景色 ARGB hex
  final int? textColor;

  const ScriptCharacter({
    required this.char,
    required this.rawIndex,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikeThrough = false,
    this.fontSizeRatio,
    this.fontSizePx,
    this.backgroundColor,
    this.textColor,
  });
}

/// 文本行，包含一组字符
class ScriptLine {
  final List<ScriptCharacter> characters;
  final int lineIndex;

  const ScriptLine({required this.characters, required this.lineIndex});

  /// 获取行纯文本
  String get text => characters.map((c) => c.char).join();
}
