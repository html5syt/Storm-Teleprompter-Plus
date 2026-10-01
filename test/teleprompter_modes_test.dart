import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storm_teleprompter_plus/models/app_settings.dart';
import 'package:storm_teleprompter_plus/models/article.dart';
import 'package:storm_teleprompter_plus/pages/teleprompter_page.dart';
import 'package:storm_teleprompter_plus/providers/article_provider.dart';
import 'package:storm_teleprompter_plus/providers/connection_provider.dart';
import 'package:storm_teleprompter_plus/providers/settings_provider.dart';
import 'package:storm_teleprompter_plus/providers/teleprompter_provider.dart';
import 'package:storm_teleprompter_plus/widgets/teleprompter/teleprompter_settings_panel.dart';
import 'package:storm_teleprompter_plus/widgets/teleprompter/teleprompter_text_layer.dart';

/// 页面级验证真实标签、设置面板和键盘交互，不仅检查模型状态。
void main() {
  for (final width in [390.0, 1000.0]) {
    testWidgets('模式切换、负速度键盘调节及阅读区域隐藏（宽度 $width）', (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      await settings.setFullScreenMode(false);
      final article = Article(
        id: 'test',
        title: '模式测试',
        content: List.filled(40, '测试正文滚动模式。').join('\n'),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final teleprompter = TeleprompterProvider()
        ..loadScript(article.id, article.content);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<TeleprompterProvider>.value(
              value: teleprompter,
            ),
            ChangeNotifierProvider(create: (_) => ConnectionProvider()),
            ChangeNotifierProvider(create: (_) => ArticleProvider()),
          ],
          child: MaterialApp(home: TeleprompterPage(article: article)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('自动-按行'), findsOneWidget);
      expect(find.text('READING AREA'), findsOneWidget);
      await tester.tap(find.text('自动-按行'));
      await tester.pumpAndSettle();
      expect(find.text('自动-滚动'), findsOneWidget);
      expect(find.text('READING AREA'), findsNothing);
      expect(find.text('像素/秒'), findsOneWidget);
      tester
          .widget<TeleprompterTextLayer>(find.byType(TeleprompterTextLayer))
          .scrollController
          .jumpTo(150);
      await settings.setAutoSpeed(5);
      teleprompter.play(settings.mergedSettings);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(settings.mergedSettings.pixelsPerSecond, -5);
      await settings.setAutoSpeed(0);
      await tester.pump();
      final layer = tester.widget<TeleprompterTextLayer>(
        find.byType(TeleprompterTextLayer),
      );
      expect(layer.physics, isA<NeverScrollableScrollPhysics>());
      layer.scrollController.jumpTo(150);
      await tester.pump();
      final stopped = layer.scrollController.offset;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
      await tester.pump(const Duration(milliseconds: 300));
      expect(layer.scrollController.offset, stopped);
      expect(settings.mergedSettings.pixelsPerSecond, 0);
      // 零速上下键和滚轮仍用于调速，不再直接移动视口。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(settings.mergedSettings.pixelsPerSecond, 10);
      await settings.setAutoSpeed(0);
      await tester.pump();
      final pointerPosition = tester.getCenter(find.byType(CustomScrollView));
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: pointerPosition,
          scrollDelta: const Offset(0, -20),
        ),
      );
      await tester.pump();
      expect(settings.mergedSettings.pixelsPerSecond, -15);
      await settings.setAutoSpeed(0);
      await tester.pump();
      // 按行模式保持零速可拖动，且模式切换不丢失零速设置。
      await settings.toggleAutoScrollMode();
      await settings.setAutoSpeed(0);
      await tester.pump(const Duration(milliseconds: 300));
      final lineLayer = tester.widget<TeleprompterTextLayer>(
        find.byType(TeleprompterTextLayer),
      );
      expect(lineLayer.physics, isA<ClampingScrollPhysics>());
      final beforeDrag = lineLayer.scrollController.offset;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 300));
      expect(lineLayer.scrollController.offset, isNot(beforeDrag));
      expect(settings.mergedSettings.wpm, 0);
      await settings.toggleAutoScrollMode();
      await tester.pump();
      teleprompter.pause(settings.mergedSettings);
      await tester.pumpAndSettle();
      // 匀速完成后重播必须重置视口，而不是留在末尾立即再次完成。
      layer.scrollController.jumpTo(
        layer.scrollController.position.maxScrollExtent,
      );
      teleprompter.play(settings.mergedSettings);
      teleprompter.finishContinuousScroll(atStart: false);
      await settings.setAutoSpeed(20);
      teleprompter.togglePlayPause(settings.mergedSettings);
      await tester.pump();
      await tester.pump();
      expect(layer.scrollController.offset, closeTo(0, 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(layer.scrollController.offset, greaterThan(0));
      teleprompter.pause(settings.mergedSettings);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('设置'));
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      final panel = find.byType(TeleprompterSettingsPanel);
      expect(panel, findsOneWidget);
      final list = find
          .descendant(of: panel, matching: find.byType(Scrollable))
          .first;
      await tester.drag(list, const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(find.text('阅读区域框'), findsNothing);
      expect(tester.takeException(), isNull);
      // 直接应用语音设置以避免测试依赖下载语音模型。
      await settings.setScrollMode(ScrollMode.asr);
      await tester.pumpAndSettle();
      expect(find.text('自动'), findsOneWidget);
      expect(find.text('READING AREA'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      teleprompter.dispose();
      settings.dispose();
    });
  }
}
