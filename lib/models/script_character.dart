class ScriptCharacter {
  final String char;
  final int rawIndex;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikeThrough;
  final double? fontSizeRatio; 
  final double? fontSizePx; 
  final int? backgroundColor; 
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

class ScriptLine {
  final List<ScriptCharacter> characters;
  final int lineIndex;

  const ScriptLine({required this.characters, required this.lineIndex});

  String get text => characters.map((c) => c.char).join();
}
