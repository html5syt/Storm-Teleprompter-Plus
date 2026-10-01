import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/models/app_settings.dart';
import 'package:storm_teleprompter_plus/models/article.dart';
import 'package:storm_teleprompter_plus/pages/editor_page.dart';
import 'package:storm_teleprompter_plus/pages/about_page.dart';
import 'package:storm_teleprompter_plus/pages/home_page.dart';
import 'package:storm_teleprompter_plus/pages/settings_page.dart';
import 'package:storm_teleprompter_plus/pages/teleprompter_page.dart';
import 'package:storm_teleprompter_plus/widgets/editor/quick_library_overlay.dart';
import 'support/quick_workspace_test_host.dart';

/// 验证真实首页悬浮层和内部设置导航，覆盖宽窄窗口和亮暗主题。
void main() {
  for (final width in [390.0, 1200.0]) {
    for (final mode in [AppBrightnessMode.light, AppBrightnessMode.dark]) {
      testWidgets('稿件管理及设置保持边距、逐层返回并保留草稿（$width，${mode.name}）', (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = QuickTestSettings();
        await settings.setQuickMode(enabled: true);
        await settings.setAppBrightnessMode(mode);
        final articles = QuickTestArticles();
        await mountQuickWorkspace(tester, const HomePage(), articles, settings);
        final editor = quickEditor(tester);
        await tester.enterText(find.byType(TextField).first, '悬浮层背后的临时稿');
        editor.quillController.replaceText(
          0,
          0,
          '正文保留',
          const TextSelection.collapsed(offset: 2),
        );
        await tester.pump();
        final selection = editor.quillController.selection;
        await tester.tap(find.byTooltip('稿件管理'));
        await tester.pumpAndSettle();
        expect(find.byType(QuickLibraryOverlay), findsOneWidget);
        expect(find.byType(EditorPage), findsOneWidget);
        final margin = width < 600 ? 12.0 : 24.0;
        final expected = Rect.fromLTWH(
          margin,
          margin,
          width - margin * 2,
          850 - margin * 2,
        );
        final panel = find.byKey(const ValueKey('quick-library-panel'));
        expect(tester.getRect(panel), expected);
        expect(
          tester.getRect(find.byType(EditorPage)),
          Rect.fromLTWH(0, 0, width, 850),
        );
        final overlay = tester.widget<QuickLibraryOverlay>(
          find.byType(QuickLibraryOverlay),
        );
        final navigator = overlay.navigatorKey.currentState!;
        final rootNavigator = Navigator.of(
          tester.element(find.byType(HomePage)),
        );
        expect(navigator, isNot(same(rootNavigator)));
        await tester.tap(find.byTooltip('设置'));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(tester.getRect(find.byType(SettingsPage)), expected);
        expect(
          Navigator.of(tester.element(find.byType(SettingsPage))),
          same(navigator),
        );
        expect(tester.getRect(panel), expected);
        await settings.setAppBrightnessMode(
          mode == AppBrightnessMode.dark
              ? AppBrightnessMode.light
              : AppBrightnessMode.dark,
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(panel), expected);
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(overlay.navigatorKey.currentState, same(navigator));
        // 系统返回优先退出设置，不会关闭编辑器或弹出未保存提示。
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(SettingsPage), findsNothing);
        expect(find.byType(QuickLibraryOverlay), findsOneWidget);
        expect(find.text('保存临时稿件？'), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(QuickLibraryOverlay), findsNothing);
        expect(quickEditor(tester), same(editor));
        expect(editor.titleController.text, '悬浮层背后的临时稿');
        expect(editor.quillController.document.toPlainText(), contains('正文保留'));
        expect(editor.quillController.selection, selection);
        expect(articles.writes, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('设置返回按钮和 Escape 均逐层退出，点击面板外侧只关闭面板', (tester) async {
    final settings = QuickTestSettings();
    await settings.setQuickMode(enabled: true);
    await mountQuickWorkspace(
      tester,
      const HomePage(),
      QuickTestArticles(),
      settings,
    );
    final editor = quickEditor(tester);
    await tester.tap(find.byTooltip('稿件管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(QuickLibraryOverlay), findsOneWidget);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.byType(QuickLibraryOverlay), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(QuickLibraryOverlay), findsNothing);
    await tester.tap(find.byTooltip('稿件管理'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(3, 3));
    await tester.pumpAndSettle();
    expect(find.byType(QuickLibraryOverlay), findsNothing);
    expect(quickEditor(tester), same(editor));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('选择其他稿件退出整个悬浮工作区，在主导航中打开提词器', (tester) async {
    final settings = QuickTestSettings();
    await settings.setQuickMode(enabled: true);
    await settings.setFullScreenMode(false);
    final articles = QuickTestArticles();
    articles.upsertArticle(
      Article(
        id: 'saved',
        title: '已保存的稿件',
        content: '正文',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await mountQuickWorkspace(tester, const HomePage(), articles, settings);
    final rootNavigator = Navigator.of(tester.element(find.byType(HomePage)));
    await tester.tap(find.byTooltip('稿件管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已保存的稿件').first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('已保存的稿件').first);
    await tester.pumpAndSettle();
    expect(find.byType(TeleprompterPage), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(TeleprompterPage))),
      same(rootNavigator),
    );
    expect(find.byType(QuickLibraryOverlay, skipOffstage: false), findsNothing);
    expect(find.byType(EditorPage, skipOffstage: false), findsNothing);
    rootNavigator.pop();
    await tester.pumpAndSettle();
    expect(find.byTooltip('回到编辑器'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('设置的关于子页面始终在悬浮层内，窗口缩放后逐层返回', (tester) async {
    tester.view.physicalSize = const Size(1000, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = QuickTestSettings();
    await settings.setQuickMode(enabled: true);
    await mountQuickWorkspace(
      tester,
      const HomePage(),
      QuickTestArticles(),
      settings,
    );
    final editor = quickEditor(tester);
    editor.titleController.text = '保留的临时标题';
    await tester.tap(find.byTooltip('稿件管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    final settingsScroll = find
        .descendant(
          of: find.byType(SettingsPage),
          matching: find.byType(Scrollable),
        )
        .first;
    final aboutLink = find.text('关于飓风提词器 Plus');
    await tester.scrollUntilVisible(aboutLink, 450, scrollable: settingsScroll);
    await tester.tap(aboutLink);
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('quick-library-panel'));
    final overlay = tester.widget<QuickLibraryOverlay>(
      find.byType(QuickLibraryOverlay),
    );
    expect(find.byType(AboutPage), findsOneWidget);
    expect(tester.getRect(find.byType(AboutPage)), tester.getRect(panel));
    expect(
      Navigator.of(tester.element(find.byType(AboutPage))),
      same(overlay.navigatorKey.currentState),
    );
    tester.view.physicalSize = const Size(390, 780);
    await tester.pumpAndSettle();
    expect(tester.getRect(panel), const Rect.fromLTWH(12, 12, 366, 756));
    expect(tester.getRect(find.byType(AboutPage)), tester.getRect(panel));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AboutPage), findsNothing);
    expect(find.byType(SettingsPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.byType(QuickLibraryOverlay), findsOneWidget);
    await tester.tap(find.byTooltip('回到编辑器'));
    await tester.pumpAndSettle();
    expect(quickEditor(tester), same(editor));
    expect(editor.titleController.text, '保留的临时标题');
    expect(find.text('保存临时稿件？'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
