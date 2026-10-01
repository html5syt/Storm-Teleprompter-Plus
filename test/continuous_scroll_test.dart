import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/models/app_settings.dart';
import 'package:storm_teleprompter_plus/providers/settings_provider.dart';
import 'package:storm_teleprompter_plus/providers/teleprompter_provider.dart';
import 'package:storm_teleprompter_plus/services/text_parser.dart';
import 'package:storm_teleprompter_plus/utils/constants.dart';
import 'package:storm_teleprompter_plus/widgets/teleprompter/auto_speed_picker.dart';
import 'package:storm_teleprompter_plus/widgets/teleprompter/teleprompter_text_layer.dart';

/// 构建足够长且具有不同字号、换行的真实正文层。
Widget _layer(
  ScrollController controller, {
  double speed = 40,
  bool playing = true,
  bool continuous = true,
  int index = 2,
  double? remoteProgress,
  void Function(bool)? boundary,
}) {
  return MaterialApp(
    home: Scaffold(
      body: TeleprompterTextLayer(
        scrollController: controller,
        lines: TextParser.parse(
          List.filled(
            50,
            '<p>正常正文用于检验匀速。</p><p><span style="font-size: 90px">大字行</span></p>',
          ).join(),
        ),
        currentIndex: index,
        fontSize: 40,
        lineHeight: 1.5,
        mirrorMode: false,
        continuous: continuous,
        isPlaying: playing,
        pixelsPerSecond: speed,
        remoteProgress: remoteProgress,
        onScrollBoundary: boundary,
        highlightCurrentChar: true,
        underlineCurrentChar: true,
        grayReadChars: true,
      ),
    ),
  );
}

void main() {
  test('自动模式和带符号速度完整保存到全局、稿件和备份映射', () {
    final settings = const AppSettings().copyWith(
      autoScrollMode: AutoScrollMode.continuous,
      pixelsPerSecond: -12.5,
      wpm: -180,
    );
    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.isContinuousScroll, isTrue);
    expect(restored.autoSpeed, -12.5);
    final merged = const AppSettings().mergeOverrides(
      settings.toTeleprompterMap(),
    );
    expect(merged.pixelsPerSecond, -12.5);
    expect(merged.wpm, -180);
    expect(AppSettings.fromJson({}).autoScrollMode, AutoScrollMode.line);
    expect(
      merged.copyWith(scrollMode: ScrollMode.asr).isContinuousScroll,
      isFalse,
    );
    expect(TeleprompterConstants.pixelSpeedPresets.length, 10);
    final sorted = [...TeleprompterConstants.pixelSpeedPresets]..sort();
    expect(TeleprompterConstants.pixelSpeedPresets, sorted);
  });

  test('两种模式保存各自速度，滚轮可跨零且倍率不变', () async {
    final settings = SettingsProvider();
    final teleprompter = TeleprompterProvider()..loadScript('test', '正文测试');
    await settings.setWpm(5);
    teleprompter.play(settings.mergedSettings);
    teleprompter.adjustSpeedByWheel(-1, settings);
    expect(settings.mergedSettings.wpm, -10);
    teleprompter.adjustSpeedByWheel(-1, settings, stepMultiplier: 4);
    expect(settings.mergedSettings.wpm, -70);
    await settings.toggleAutoScrollMode();
    await settings.setAutoSpeed(-12.5);
    teleprompter.adjustSpeedByWheel(1, settings);
    expect(settings.mergedSettings.pixelsPerSecond, 2.5);
    await settings.toggleAutoScrollMode();
    expect(settings.mergedSettings.wpm, -70);
    teleprompter.dispose();
    settings.dispose();
  });

  test('按行模式负速度向前移动，在开头暂停，正向仍正常完成', () async {
    final provider = TeleprompterProvider()
      ..loadScript('test', List.filled(200, '字').join());
    const reverse = AppSettings(wpm: -6000, autoHideUI: false);
    provider.setCurrentIndex(150);
    provider.play(reverse);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(provider.currentIndex, lessThan(150));
    expect(provider.currentIndex, greaterThan(0));
    provider.setCurrentIndex(1);
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(provider.currentIndex, 0);
    expect(provider.state, TeleprompterState.paused);
    provider.setCurrentIndex(198);
    provider.play(reverse.copyWith(wpm: 6000));
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(provider.state, TeleprompterState.completed);
    provider.togglePlayPause(reverse);
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(provider.currentIndex, lessThan(199));
    expect(provider.currentIndex, greaterThan(0));
    provider.dispose();
  });

  testWidgets('匀速按帧时间滚动，不受字号影响，支持反向、暂停和边界', (tester) async {
    final controller = ScrollController();
    final boundaries = <bool>[];
    await tester.pumpWidget(_layer(controller, boundary: boundaries.add));
    await tester.pump();
    final start = controller.offset;
    await tester.pump(const Duration(seconds: 1));
    expect(controller.offset - start, closeTo(40, 0.01));
    final before = controller.offset;
    await tester.pump(const Duration(milliseconds: 250));
    expect(controller.offset - before, closeTo(10, 0.01));
    await tester.pumpWidget(
      _layer(controller, speed: -20, boundary: boundaries.add),
    );
    final reverseStart = controller.offset;
    await tester.pump(const Duration(seconds: 1));
    expect(controller.offset, closeTo(reverseStart - 20, 0.01));
    await tester.pumpWidget(
      _layer(controller, speed: 0, boundary: boundaries.add),
    );
    final paused = controller.offset;
    await tester.pump(const Duration(seconds: 1));
    expect(controller.offset, paused);
    // 滚动模式零速固定页面，拖动不能改变位置。
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(controller.offset, paused);
    final stopped = controller.offset;
    await tester.pump(const Duration(seconds: 1));
    expect(controller.offset, stopped);
    controller.jumpTo(2);
    await tester.pumpWidget(
      _layer(controller, speed: -40, boundary: boundaries.add),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.offset, 0);
    expect(boundaries, [true]);
    await tester.pumpWidget(_layer(controller, speed: 0));
    controller.jumpTo(controller.position.maxScrollExtent - 2);
    await tester.pumpWidget(
      _layer(controller, speed: 40, boundary: boundaries.add),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.offset, controller.position.maxScrollExtent);
    expect(boundaries, [true, false]);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('匀速不显示当前字样式且不随游标跳动，远程首帧恢复视口', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(_layer(controller, speed: 0));
    await tester.pump();
    final richText = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((w) => w.text.toPlainText().contains('正常正文'));
    final spans = (richText.text as TextSpan).children!.cast<TextSpan>();
    for (final span in spans) {
      expect(span.style!.decoration, TextDecoration.none);
      expect(span.style!.fontWeight, FontWeight.w400);
      expect(span.style!.color!.a, 1);
    }
    controller.jumpTo(123);
    await tester.pumpWidget(_layer(controller, speed: 0, index: 200));
    await tester.pumpAndSettle();
    expect(controller.offset, 123);
    await tester.pumpWidget(_layer(controller, remoteProgress: 0.5));
    await tester.pump();
    expect(
      controller.offset,
      closeTo(controller.position.maxScrollExtent * 0.5, 0.01),
    );
    final remoteOffset = controller.offset;
    await tester.pump(const Duration(seconds: 1));
    expect(controller.offset, remoteOffset);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('速度面板可自由输入负小数，十档预设保持反向', (tester) async {
    final provider = SettingsProvider();
    await provider.toggleAutoScrollMode();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAutoSpeedPicker(context, provider),
              child: const Text('速度'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('速度'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(10));
    await tester.enterText(find.byType(TextField), '-12.5');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(provider.mergedSettings.pixelsPerSecond, -12.5);
    await tester.tap(find.text('速度'));
    await tester.pumpAndSettle();
    expect(find.text('-10 像素/秒'), findsOneWidget);
    await tester.tap(find.text('-10 像素/秒'));
    await tester.pumpAndSettle();
    expect(provider.mergedSettings.pixelsPerSecond, -10);
    expect(autoSpeedText(provider.mergedSettings), '-10');
    provider.dispose();
  });
}
