import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/pages/home_page.dart';
import 'support/quick_workspace_test_host.dart';

/// 退出请求去重覆盖弹窗显示、退场动画和选择保存位置三个阶段。
void main() {
  testWidgets('连续关闭和系统退出只出现一个确认，取消退场期间不会再次弹出', (tester) async {
    final settings = QuickTestSettings();
    await settings.setQuickMode(enabled: true);
    final articles = QuickTestArticles();
    await mountQuickWorkspace(tester, const HomePage(), articles, settings);
    final editor = quickEditor(tester);
    editor.titleController.text = '退出去重';
    await tester.pump();
    final dynamic home = tester.state(find.byType(HomePage));
    home.onWindowClose();
    home.onWindowClose();
    final exit = tester.binding.handleRequestAppExit();
    await tester.pumpAndSettle();
    expect(find.text('保存临时稿件？', skipOffstage: false), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pump(const Duration(milliseconds: 10));
    home.onWindowClose();
    await tester.pumpAndSettle();
    expect(find.text('保存临时稿件？', skipOffstage: false), findsNothing);
    expect((await exit).name, 'cancel');
    expect(editor.isDirty, isTrue);
    expect(articles.writes, 0);
    // 完全退出上一轮确认后仍可再次正常请求关闭。
    home.onWindowClose();
    await tester.pumpAndSettle();
    expect(find.text('保存临时稿件？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('保存位置打开时连续保存和退出共享同一次选择', (tester) async {
    final settings = QuickTestSettings();
    await settings.setQuickMode(enabled: true);
    final articles = QuickTestArticles();
    await mountQuickWorkspace(tester, const HomePage(), articles, settings);
    final editor = quickEditor(tester);
    editor.titleController.text = '只保存一份';
    await tester.pump();
    final first = editor.manualSave();
    final second = editor.manualSave();
    final leave = editor.confirmLeave();
    await tester.pumpAndSettle();
    expect(find.text('选择保存位置', skipOffstage: false), findsOneWidget);
    expect(find.text('保存临时稿件？', skipOffstage: false), findsNothing);
    await tester.tap(find.text('根目录'));
    await tester.pumpAndSettle();
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(await leave, isTrue);
    expect(articles.writes, 1);
    expect(articles.articles, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('退出确认选择保存后重复关闭只保留一个目录，取消和失败均保留草稿', (tester) async {
    final settings = QuickTestSettings();
    await settings.setQuickMode(enabled: true);
    final articles = QuickTestArticles();
    await mountQuickWorkspace(tester, const HomePage(), articles, settings);
    final editor = quickEditor(tester);
    editor.titleController.text = '安全退出';
    await tester.pump();
    final dynamic home = tester.state(find.byType(HomePage));
    for (final fail in [false, true]) {
      home.onWindowClose();
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      home.onWindowClose();
      final exit = tester.binding.handleRequestAppExit();
      await tester.pumpAndSettle();
      expect(find.text('选择保存位置', skipOffstage: false), findsOneWidget);
      expect(find.text('保存临时稿件？', skipOffstage: false), findsNothing);
      articles.fail = fail;
      await tester.tap(find.text(fail ? '根目录' : '取消'));
      await tester.pumpAndSettle();
      expect((await exit).name, 'cancel');
      expect(find.byType(AlertDialog, skipOffstage: false), findsNothing);
      expect(editor.isDirty, isTrue);
      expect(editor.titleController.text, '安全退出');
    }
    expect(articles.articles, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
