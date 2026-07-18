import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:storm_teleprompter_plus/models/article.dart';
import 'package:storm_teleprompter_plus/pages/editor_page.dart';
import 'package:storm_teleprompter_plus/providers/article_provider.dart';
import 'package:storm_teleprompter_plus/providers/settings_provider.dart';
import 'package:storm_teleprompter_plus/providers/teleprompter_provider.dart';
import 'package:storm_teleprompter_plus/widgets/common/app_color_picker_dialog.dart';

class _DelayedArticleProvider extends ArticleProvider {
  final completer = Completer<Article?>();

  @override
  Future<Article?> updateArticle(String id, {String? title, String? content}) =>
      completer.future;
}

void main() {
  testWidgets('editor page lays out with quill toolbar', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ArticleProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => TeleprompterProvider()),
        ],
        child: MaterialApp(
          localizationsDelegates:
              quill.FlutterQuillLocalizations.localizationsDelegates,
          supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
          home: const EditorPage(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(EditorPage), findsOneWidget);
    final toolbar = tester.widget<quill.QuillSimpleToolbar>(
      find.byType(quill.QuillSimpleToolbar),
    );
    expect(toolbar.config.showColorButton, isFalse);
    expect(toolbar.config.showBackgroundColorButton, isFalse);
    expect(find.byTooltip('字体颜色'), findsOneWidget);
    expect(find.byTooltip('文字背景色'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('editor color button opens the shared color picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ArticleProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => TeleprompterProvider()),
        ],
        child: MaterialApp(
          localizationsDelegates:
              quill.FlutterQuillLocalizations.localizationsDelegates,
          supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
          home: const EditorPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.byTooltip('字体颜色'));
    await tester.pumpAndSettle();

    expect(find.byType(AppColorPickerDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppColorPickerDialog),
        matching: find.byType(TextField),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor accepts stored px font size html', (tester) async {
    final now = DateTime(2026);
    final article = Article(
      id: 'article-font-size',
      title: '字号测试',
      content: '<p><span style="font-size: 50px">大字</span></p>',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ArticleProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => TeleprompterProvider()),
        ],
        child: MaterialApp(
          localizationsDelegates:
              quill.FlutterQuillLocalizations.localizationsDelegates,
          supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
          home: EditorPage(article: article),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(EditorPage), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('stored background color does not become text color', (
    tester,
  ) async {
    final now = DateTime(2026);
    final article = Article(
      id: 'article-background-color',
      title: '背景色测试',
      content: '<p><span style="background-color: #FFFF00FF">背景</span></p>',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ArticleProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => TeleprompterProvider()),
        ],
        child: MaterialApp(
          localizationsDelegates:
              quill.FlutterQuillLocalizations.localizationsDelegates,
          supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
          home: EditorPage(article: article),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1));
    final editor = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    final attributes = editor.controller.document
        .toDelta()
        .operations
        .first
        .attributes;

    expect(attributes?['background'], '#FFFF00FF');
    expect(attributes?['color'], isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('teleprompter start requires visible body text', (tester) async {
    final now = DateTime(2026);

    Future<void> pumpEditor(String content) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ArticleProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => TeleprompterProvider()),
          ],
          child: MaterialApp(
            localizationsDelegates:
                quill.FlutterQuillLocalizations.localizationsDelegates,
            supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
            home: EditorPage(
              key: ValueKey(content),
              article: Article(
                id: content.hashCode.toString(),
                title: '测试',
                content: content,
                createdAt: now,
                updatedAt: now,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
    }

    await pumpEditor('<p> \u200B\uFEFF </p>');
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await pumpEditor('<p>可见正文</p>');
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('pending autosave can finish after editor disposal', (
    tester,
  ) async {
    final provider = _DelayedArticleProvider();
    final now = DateTime(2026);
    final article = Article(
      id: 'pending-save',
      title: '原标题',
      content: '<p>正文</p>',
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ArticleProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => TeleprompterProvider()),
        ],
        child: MaterialApp(
          localizationsDelegates:
              quill.FlutterQuillLocalizations.localizationsDelegates,
          supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
          home: EditorPage(article: article),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.enterText(find.byType(TextField).first, '新标题');
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpWidget(const SizedBox.shrink());
    provider.completer.complete(article.copyWith(title: '新标题'));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
