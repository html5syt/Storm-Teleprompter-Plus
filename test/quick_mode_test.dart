import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/models/app_settings.dart';
import 'package:storm_teleprompter_plus/models/article.dart';
import 'package:storm_teleprompter_plus/pages/editor_page.dart';
import 'package:storm_teleprompter_plus/pages/home_page.dart';
import 'package:storm_teleprompter_plus/pages/teleprompter_page.dart';
import 'package:storm_teleprompter_plus/widgets/settings/quick_mode_settings_section.dart';
import 'support/quick_workspace_test_host.dart';

void main() {
  test('快速模式默认关闭并完整序列化，不混入稿件覆盖', () {
    const defaults = AppSettings();
    expect(defaults.quickModeEnabled, isFalse);
    expect(defaults.quickModeAutoSave, isFalse);
    expect(defaults.quickModeFolderId, '');
    final settings = defaults.copyWith(
      quickModeEnabled: true,
      quickModeAutoSave: true,
      quickModeFolderId: 'folder',
    );
    final restored = AppSettings.fromJson(
      settings.toJson(),
    ).mergeOverrides({'fontSize': 80});
    expect(restored.quickModeEnabled, isTrue);
    expect(restored.quickModeAutoSave, isTrue);
    expect(restored.quickModeFolderId, 'folder');
    expect(
      restored.toTeleprompterMap().containsKey('quickModeEnabled'),
      isFalse,
    );
  });

  testWidgets('手动保存选择位置；失败和取消保留草稿；销毁不偷存', (tester) async {
    final articles = QuickTestArticles();
    final settings = QuickTestSettings();
    await mountQuickWorkspace(
      tester,
      const EditorPage(quickMode: true, autoSave: false),
      articles,
      settings,
    );
    await tester.enterText(find.byType(TextField).first, '临时稿件');
    await tester.pump(const Duration(seconds: 2));
    expect(articles.writes, 0);
    expect(find.text('未保存'), findsOneWidget);
    final state = quickEditor(tester);
    final canceled = state.confirmLeave();
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await canceled, isFalse);
    articles.fail = true;
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('根目录 / 测试目录'));
    await tester.pumpAndSettle();
    expect(state.isDirty, isTrue);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    articles.fail = false;
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('根目录 / 测试目录'));
    await tester.pumpAndSettle();
    expect(articles.articles.single.folderId, 'folder');
    expect(state.isDirty, isFalse);
    expect(await state.confirmLeave(), isTrue);
    await tester.enterText(find.byType(TextField).first, '第二版');
    await tester.pumpWidget(const SizedBox());
    expect(articles.writes, 2);
  });

  testWidgets('自动保存采用默认目录，只有一份稿件', (tester) async {
    final articles = QuickTestArticles();
    final settings = QuickTestSettings();
    await mountQuickWorkspace(
      tester,
      const EditorPage(quickMode: true, initialFolderId: 'folder'),
      articles,
      settings,
    );
    await tester.enterText(find.byType(TextField).first, '自动保存');
    await tester.pump(const Duration(seconds: 1));
    expect(articles.articles.single.folderId, 'folder');
    await tester.enterText(find.byType(TextField).first, '自动保存更新');
    await tester.pump(const Duration(seconds: 1));
    expect(articles.articles.single.title, '自动保存更新');
    expect(articles.writes, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('启动进入空编辑器，列表返回保留草稿，选择其他稿件结束快速会话', (tester) async {
    final articles = QuickTestArticles();
    articles.upsertArticle(
      Article(
        id: 'other',
        title: '已有稿件',
        content: '已有正文',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final settings = QuickTestSettings();
    await settings.setQuickMode(enabled: true);
    await settings.toggleFullScreenMode();
    await mountQuickWorkspace(tester, const HomePage(), articles, settings);
    expect(find.byType(EditorPage), findsOneWidget);
    final state = quickEditor(tester);
    expect(state.plainTextLength, 0);
    await tester.enterText(find.byType(TextField).first, '临时稿件');
    await tester.tap(find.byTooltip('稿件管理'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('回到编辑器'), findsOneWidget);
    // 系统返回只回到编辑器，不触发退出确认。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(quickEditor(tester), same(state));
    expect(find.text('保存临时稿件？'), findsNothing);
    await tester.tap(find.byTooltip('稿件管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已有稿件').first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('已有稿件').first);
    await tester.pumpAndSettle();
    expect(find.text('保存临时稿件？'), findsOneWidget);
    await tester.tap(find.text('不保存'));
    await tester.pumpAndSettle();
    expect(find.byType(TeleprompterPage), findsOneWidget);
    expect(articles.writes, 0);
    Navigator.of(tester.element(find.byType(TeleprompterPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byTooltip('回到编辑器'), findsNothing);
    expect(find.byType(EditorPage), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('快速开始提词使用内存正文且不强制保存', (tester) async {
    final articles = QuickTestArticles();
    final settings = QuickTestSettings();
    await settings.toggleFullScreenMode();
    await mountQuickWorkspace(
      tester,
      const EditorPage(quickMode: true, autoSave: false),
      articles,
      settings,
    );
    final state = quickEditor(tester);
    state.quillController.replaceText(
      0,
      0,
      '临时正文',
      const TextSelection.collapsed(offset: 4),
    );
    await tester.pump();
    await tester.tap(find.text('开始提词'));
    await tester.pumpAndSettle();
    final page = tester.widget<TeleprompterPage>(find.byType(TeleprompterPage));
    expect(page.article.content, contains('临时正文'));
    expect(page.persistArticleSettings, isFalse);
    expect(articles.writes, 0);
    Navigator.of(tester.element(find.byType(TeleprompterPage))).pop();
    await tester.pumpAndSettle();
    expect(state.isDirty, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('自动保存关闭时默认位置不可设置', (tester) async {
    final settings = QuickTestSettings();
    await mountQuickWorkspace(
      tester,
      const Scaffold(body: QuickModeSettingsSection()),
      QuickTestArticles(),
      settings,
    );
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, '默认保存位置')).enabled,
      isFalse,
    );
    await tester.tap(find.text('快速模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自动保存'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, '默认保存位置')).enabled,
      isTrue,
    );
  });
  testWidgets('窗口关闭和系统退出都会保护稿件管理页背后的草稿', (tester) async {
    final articles = QuickTestArticles();
    final settings = QuickTestSettings();
    await settings.setQuickMode(enabled: true);
    await mountQuickWorkspace(tester, const HomePage(), articles, settings);
    await tester.enterText(find.byType(TextField).first, '退出保护');
    await tester.tap(find.byTooltip('稿件管理'));
    await tester.pumpAndSettle();
    final dynamic homeState = tester.state(find.byType(HomePage));
    homeState.onWindowClose();
    await tester.pumpAndSettle();
    expect(find.text('保存临时稿件？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(articles.writes, 0);
    final exit = tester.binding.handleRequestAppExit();
    await tester.pumpAndSettle();
    expect(find.text('保存临时稿件？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect((await exit).name, 'cancel');
    await tester.tap(find.byTooltip('回到编辑器'));
    await tester.pumpAndSettle();
    expect(quickEditor(tester).titleController.text, '退出保护');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('默认普通启动不创建临时编辑器', (tester) async {
    final articles = QuickTestArticles();
    await mountQuickWorkspace(
      tester,
      const HomePage(),
      articles,
      QuickTestSettings(),
    );
    expect(find.byType(EditorPage), findsNothing);
    expect(find.byTooltip('回到编辑器'), findsNothing);
    expect(articles.writes, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('窄屏快速编辑器仍可保存和开始提词', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mountQuickWorkspace(
      tester,
      const EditorPage(quickMode: true, autoSave: false),
      QuickTestArticles(),
      QuickTestSettings(),
    );
    expect(find.byTooltip('保存'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).automaticallyImplyLeading,
      isFalse,
    );
    expect(find.text('未保存'), findsOneWidget);
    expect(find.text('开始提词'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
