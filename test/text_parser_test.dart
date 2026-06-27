import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/services/text_parser.dart';

void main() {
  test('normalizes mixed Chinese quote pairs', () {
    expect(TextParser.normalizeQuotePairs('’‘’'), '‘’‘');
    expect(TextParser.normalizeQuotePairs('‘’““'), '‘’“”');
    expect(TextParser.normalizeQuotePairs('"你好" \'世界\''), '“你好” ‘世界’');
  });

  test('parses rgba text color from rich text html', () {
    final lines = TextParser.parse(
      '<p><span style="color: rgba(255, 0, 0, 1)">红</span></p>',
    );

    expect(lines.first.characters.first.textColor, 0xFFFF0000);
  });

  test('parses absolute inline font size from rich text html', () {
    final lines = TextParser.parse(
      '<p><span style="font-size: 42px">大</span>小</p>',
    );

    expect(lines.first.characters[0].fontSizePx, 42);
    expect(lines.first.characters[1].fontSizePx, isNull);
  });
}
