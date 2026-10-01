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
import 'package:storm_teleprompter_plus/providers/article_provider.dart';
import 'package:storm_teleprompter_plus/providers/connection_provider.dart';
import 'package:storm_teleprompter_plus/providers/folder_provider.dart';
import 'package:storm_teleprompter_plus/providers/settings_provider.dart';
import 'package:storm_teleprompter_plus/providers/teleprompter_provider.dart';

import 'package:storm_teleprompter_plus/theme/app_theme.dart';
import 'package:storm_teleprompter_plus/theme/app_colors.dart';

/// 内存稿件仓库记录落盘行为，也可模拟写入失败。
class QuickTestArticles extends ArticleProvider {
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
class QuickTestFolders extends FolderProvider {
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
class QuickTestConnection extends ConnectionProvider {
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
class QuickTestSettings extends SettingsProvider {
  @override
  Future<void> init() async {}
}

/// 装配与应用一致的 Provider 和编辑器本地化依赖。
Future<void> mountQuickWorkspace(
  WidgetTester tester,
  Widget home,
  QuickTestArticles articles,
  QuickTestSettings settings,
) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ArticleProvider>.value(value: articles),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<FolderProvider>(
          create: (_) => QuickTestFolders(),
        ),
        ChangeNotifierProvider<ConnectionProvider>(
          create: (_) => QuickTestConnection(),
        ),
        ChangeNotifierProvider(create: (_) => TeleprompterProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, provider, _) => MaterialApp(
          theme: AppTheme.lightFromColorAndFont(AppColors.primary),
          darkTheme: AppTheme.darkTheme,
          themeMode: switch (provider.settings.appBrightnessMode) {
            AppBrightnessMode.light => ThemeMode.light,
            AppBrightnessMode.dark => ThemeMode.dark,
            AppBrightnessMode.system => ThemeMode.system,
          },
          localizationsDelegates:
              quill.FlutterQuillLocalizations.localizationsDelegates,
          supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
          home: home,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 获取编辑状态以验证保存修订和富文本内容。
EditorPageState quickEditor(WidgetTester tester) =>
    tester.state<EditorPageState>(find.byType(EditorPage));
