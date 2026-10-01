import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storm_teleprompter_plus/backend/ws_protocol.dart';
import 'package:storm_teleprompter_plus/models/app_settings.dart';
import 'package:storm_teleprompter_plus/models/article.dart';
import 'package:storm_teleprompter_plus/models/folder.dart';
import 'package:storm_teleprompter_plus/pages/editor_page.dart';
import 'package:storm_teleprompter_plus/pages/home_page.dart';
import 'package:storm_teleprompter_plus/pages/teleprompter_page.dart';
import 'package:storm_teleprompter_plus/providers/article_provider.dart';
import 'package:storm_teleprompter_plus/providers/connection_provider.dart';
import 'package:storm_teleprompter_plus/providers/folder_provider.dart';
import 'package:storm_teleprompter_plus/providers/settings_provider.dart';
import 'package:storm_teleprompter_plus/providers/teleprompter_provider.dart';
import 'package:storm_teleprompter_plus/widgets/settings/quick_mode_settings_section.dart';

/// 内存稿件仓库记录落盘行为，也可模拟写入失败。
class _Articles extends ArticleProvider {
  int writes = 0;
  bool fail = false;
  @override
  Future<void> init() async {}
  @override
  Future<Article?> createArticle({
    required String title,
    String content = '',
    String? folderId,
  }) async {
    writes++;
    if (fail) return null;
    final article = Article(
      id: 'saved-$writes',
      title: title,
      content: content,
      folderId: folderId,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    upsertArticle(article);
    return article;
  }

  @override
  Future<Article?> updateArticle(
    String id, {
    String? title,
    String? content,
  }) async {
    writes++;
    if (fail) return null;
    final article = articles
        .firstWhere((a) => a.id == id)
        .copyWith(title: title, content: content);
    upsertArticle(article);
    return article;
  }

  @override
  Future<bool> moveArticleToFolder(String id, String? folderId) async {
    upsertArticle(
      articles
          .firstWhere((a) => a.id == id)
          .copyWith(folderId: folderId, clearFolderId: folderId == null),
    );
    return true;
  }
}

/// 提供嵌套目录，验证保存位置而非仅验证对话框存在。
class _Folders extends FolderProvider {
  @override
  List<Folder> get folders => [
    Folder(id: 'folder', name: '测试目录', createdAt: DateTime(2026)),
  ];
  @override
  Folder? getFolderById(String id) => id == 'folder' ? folders.first : null;
  @override
  Future<void> init() async {}
}

/// 本地连接替身允许导航和临时提词，无须真实端口和录音设备。
class _Connection extends ConnectionProvider {
  @override
  bool get isConnected => true;
  @override
  bool get isLocal => true;
  @override
  Future<WsMessage> request(
    WsMessageType type, {
    Map<String, dynamic> data = const {},
    Duration timeout = const Duration(seconds: 10),
  }) async => WsMessage(type: type, data: data);
  @override
  void send(WsMessage message) {}
}

/// 保留测试指定的启动设置，不从服务端重新加载。
class _Settings extends SettingsProvider {
  @override
  Future<void> init() async {}
}

/// 装配与应用一致的 Provider 和编辑器本地化依赖。
Future<void> _mount(
  WidgetTester tester,
  Widget home,
  _Articles articles,
  _Settings settings,
) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ArticleProvider>.value(value: articles),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<FolderProvider>(create: (_) => _Folders()),
        ChangeNotifierProvider<ConnectionProvider>(
          create: (_) => _Connection(),
        ),
        ChangeNotifierProvider(create: (_) => TeleprompterProvider()),
      ],
      child: MaterialApp(
        localizationsDelegates:
            quill.FlutterQuillLocalizations.localizationsDelegates,
        supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 获取编辑状态以验证保存修订和富文本内容。
EditorPageState _editor(WidgetTester tester) =>
    tester.state<EditorPageState>(find.byType(EditorPage));

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
    final articles = _Articles();
    final settings = _Settings();
    await _mount(
      tester,
      const EditorPage(quickMode: true, autoSave: false),
      articles,
      settings,
    );
    await tester.enterText(find.byType(TextField).first, '临时稿件');
    await tester.pump(const Duration(seconds: 2));
    expect(articles.writes, 0);
    expect(find.text('未保存'), findsOneWidget);
    final state = _editor(tester);
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
    final articles = _Articles();
    final settings = _Settings();
    await _mount(
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
    final articles = _Articles();
    articles.upsertArticle(
      Article(
        id: 'other',
        title: '已有稿件',
        content: '已有正文',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final settings = _Settings();
    await settings.setQuickMode(enabled: true);
    await settings.toggleFullScreenMode();
    await _mount(tester, const HomePage(), articles, settings);
    expect(find.byType(EditorPage), findsOneWidget);
    final state = _editor(tester);
    expect(state.plainTextLength, 0);
    await tester.enterText(find.byType(TextField).first, '临时稿件');
    await tester.tap(find.byTooltip('稿件管理'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('回到编辑器'), findsOneWidget);
    // 系统返回只回到编辑器，不触发退出确认。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_editor(tester), same(state));
    expect(find.text('保存稿件？'), findsNothing);
    await tester.tap(find.byTooltip('稿件管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已有稿件').first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('已有稿件').first);
    await tester.pumpAndSettle();
    expect(find.text('保存稿件？'), findsOneWidget);
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
    final articles = _Articles();
    final settings = _Settings();
    await settings.toggleFullScreenMode();
    await _mount(
      tester,
      const EditorPage(quickMode: true, autoSave: false),
      articles,
      settings,
    );
    final state = _editor(tester);
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
    final settings = _Settings();
    await _mount(
      tester,
      const Scaffold(body: QuickModeSettingsSection()),
      _Articles(),
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
}
