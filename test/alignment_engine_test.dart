import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/services/asr/alignment_engine.dart';

void main() {
  test('only searches the current logical line and two surrounding lines', () {
    const script = '第一行\n第二行\n第三行\n第四行\n第五行\n第六行目标';
    final alignment = TeleprompterAlignment()..setScript(script);
    final currentIndex = script.indexOf('第三行');
    alignment.setCurrentIndex(currentIndex);

    final result = alignment.consumeTranscript('目标', false);

    expect(result.index, currentIndex);
    expect(result.meta.strategy, 'none');
  });

  test(
    'includes the two lines below the current line in the fallback window',
    () {
      const script = '第一行\n第二行\n第三行\n第四行\n第五行目标\n第六行';
      final alignment = TeleprompterAlignment()..setScript(script);
      alignment.setCurrentIndex(script.indexOf('第三行'));

      final result = alignment.consumeTranscript('目标', false);

      expect(result.index, script.indexOf('目标') + 1);
    },
  );

  test('uses the visual search window when the interface provides one', () {
    const script = '开场\n允许目标\n禁止目标';
    final alignment = TeleprompterAlignment()..setScript(script);
    alignment
      ..setCurrentIndex(script.indexOf('开场'))
      ..setSearchWindow(0, script.indexOf('允许目标') + '允许目标'.length - 1);

    final result = alignment.consumeTranscript('目标', false);

    expect(result.index, script.indexOf('允许目标') + 3);
  });

  test('keeps the startup search window after the cursor is synchronized', () {
    const script = '开场\n允许内容\n禁止目标';
    final alignment = TeleprompterAlignment()..setScript(script);
    final currentIndex = script.indexOf('开场');
    alignment
      ..setCurrentIndex(currentIndex)
      ..setSearchWindow(0, script.indexOf('允许内容') + '允许内容'.length - 1)
      ..setCurrentIndex(currentIndex);

    final result = alignment.consumeTranscript('目标', false);

    expect(result.index, currentIndex);
    expect(result.meta.strategy, 'none');
  });

  test('moves the server search window forward after reaching its end', () {
    const script = '甲乙丙丁戊己庚辛壬癸';
    final alignment = TeleprompterAlignment()..setScript(script);
    alignment
      ..setCurrentIndex(script.indexOf('甲'))
      ..setSearchWindow(script.indexOf('甲'), script.indexOf('己'));

    final first = alignment.consumeTranscript('乙丙丁戊己', true);
    final second = alignment.consumeTranscript('庚辛', true);

    expect(first.index, script.indexOf('己'));
    expect(second.index, script.indexOf('辛'));
  });

  test('does not resync to a distant occurrence in dense repeated text', () {
    const script = '今天读稿\n今天读稿\n甲乙丙\n甲乙丙丁戊己庚辛壬癸\n今天读稿';
    final alignment = TeleprompterAlignment()..setScript(script);
    final currentIndex = script.indexOf('甲乙丙');
    alignment.setCurrentIndex(currentIndex);

    final result = alignment.consumeTranscript('今天', false);

    expect(result.index, currentIndex);
    expect(result.meta.strategy, 'none');
  });
}
