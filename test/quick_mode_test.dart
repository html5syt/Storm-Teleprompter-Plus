import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:storm_teleprompter_plus/models/app_settings.dart';
import 'package:storm_teleprompter_plus/pages/editor_page.dart';
import 'package:storm_teleprompter_plus/pages/quick_mode_app_host.dart';
import 'package:storm_teleprompter_plus/providers/article_provider.dart';
import 'package:storm_teleprompter_plus/providers/folder_provider.dart';
import 'package:storm_teleprompter_plus/providers/settings_provider.dart';
import 'package:storm_teleprompter_plus/providers/teleprompter_provider.dart';
import 'package:storm_teleprompter_plus/providers/connection_provider.dart';
import 'package:storm_teleprompter_plus/services/quick_mode_controller.dart';

void main() {
  testWidgets('Quick mode editor displays save button and unsaved label when autosave is off', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ConnectionProvider()),
          ChangeNotifierProvider(create: (_) => ArticleProvider()),
          ChangeNotifierProvider(create: (_) => FolderProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => TeleprompterProvider()),
        ],
        child: MaterialApp(
          localizationsDelegates:
              quill.FlutterQuillLocalizations.localizationsDelegates,
          supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
          home: const EditorPage(
            isQuickMode: true,
            quickModeAutosave: false,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1));

    // 应展示保存按钮
    expect(find.widgetWithText(OutlinedButton, '保存'), findsOneWidget);
    // 初始状态没有编辑内容，不显示未保存
    expect(find.text('未保存'), findsNothing);

    // 输入标题触发变更
    await tester.enterText(find.byType(TextField).first, '快速模式测试稿件');
    await tester.pump(const Duration(milliseconds: 1));

    // 未保存文字应出现
    expect(find.text('未保存'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('QuickModeAppHost hosts editor and manages view switching', (
    tester,
  ) async {
    final settingsProvider = SettingsProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ConnectionProvider()),
          ChangeNotifierProvider(create: (_) => ArticleProvider()),
          ChangeNotifierProvider(create: (_) => FolderProvider()),
          ChangeNotifierProvider.value(value: settingsProvider),
          ChangeNotifierProvider(create: (_) => TeleprompterProvider()),
        ],
        child: MaterialApp(
          localizationsDelegates:
              quill.FlutterQuillLocalizations.localizationsDelegates,
          supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
          home: const QuickModeAppHost(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1));

    // QuickModeController 应该是 active 状态
    expect(QuickModeController.instance.isActive, isTrue);

    // 初始展示编辑器
    expect(find.byType(EditorPage), findsOneWidget);
    // 浮动按钮应存在
    expect(find.byTooltip('打开稿件管理'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
