import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/services/inline_style_parser.dart';

void main() {
  test('background color does not leak into text color', () {
    const style = 'background-color: #FFFF00FF';

    expect(InlineStyleParser.color(style, 'background-color'), '#FFFF00FF');
    expect(InlineStyleParser.color(style, 'color'), isNull);
  });

  test('extracts adjacent text and background colors independently', () {
    const style = 'color: #FFFFFF00; background-color: rgba(255, 0, 255, 1)';

    expect(InlineStyleParser.color(style, 'color'), '#FFFFFF00');
    expect(
      InlineStyleParser.color(style, 'background-color'),
      'rgba(255, 0, 255, 1)',
    );
  });

  test('does not match similarly named properties', () {
    const style = 'border-color: #FF000000; background: #FFFFFFFF';

    expect(InlineStyleParser.color(style, 'color'), isNull);
    expect(InlineStyleParser.color(style, 'background'), '#FFFFFFFF');
  });
}
