import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:storm_teleprompter_plus/pages/editor_page.dart';
import 'package:storm_teleprompter_plus/providers/article_provider.dart';
import 'package:storm_teleprompter_plus/providers/settings_provider.dart';
import 'package:storm_teleprompter_plus/widgets/editor/editor_toolbar.dart';
import 'package:storm_teleprompter_plus/widgets/editor/editor_toolbar_style.dart';

/// 编辑器工具栏统一几何布局且保留 Quill 真实编辑行为。
void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets('按钮统一尺寸和对齐，窄屏可滚动访问格式工具（$width）', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ArticleProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: MaterialApp(
            localizationsDelegates:
                quill.FlutterQuillLocalizations.localizationsDelegates,
            supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
            home: const EditorPage(quickMode: true, autoSave: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final toolbar = find.byType(EditorToolbar);
      final buttons = find.descendant(
        of: toolbar,
        matching: find.byType(IconButton),
      );
      expect(buttons, findsNWidgets(15));
      expect(tester.getSize(toolbar).width, width - 25);
      expect(
        tester.getTopLeft(buttons.first).dx,
        tester.getTopLeft(toolbar).dx + 8,
      );
      final top = tester.getTopLeft(buttons.first).dy;
      for (final element in buttons.evaluate()) {
        final button = find.byElementPredicate(
          (candidate) => identical(candidate, element),
        );
        expect(
          tester.getSize(button),
          const Size.square(EditorToolbarStyle.buttonSize),
        );
        expect(tester.getTopLeft(button).dy, top);
        final icon = find.descendant(of: button, matching: find.byType(Icon));
        expect(
          tester.getSize(icon),
          const Size.square(EditorToolbarStyle.iconSize),
        );
      }
      final input = find.descendant(
        of: toolbar,
        matching: find.byType(TextField),
      );
      expect(
        tester.getSize(input),
        const Size.square(EditorToolbarStyle.buttonSize),
      );
      expect(tester.getTopLeft(input).dy, top);
      expect(
        tester
            .getSize(
              find.descendant(of: input, matching: find.byType(InputDecorator)),
            )
            .height,
        EditorToolbarStyle.buttonSize,
      );
      final editor = tester.state<EditorPageState>(find.byType(EditorPage));
      editor.quillController.replaceText(
        0,
        0,
        '格式测试',
        const TextSelection(baseOffset: 0, extentOffset: 4),
      );
      await tester.pump();
      await tester.ensureVisible(find.byTooltip('加粗'));
      await tester.tap(find.byTooltip('加粗'));
      await tester.pumpAndSettle();
      expect(
        editor.quillController
            .getSelectionStyle()
            .attributes[quill.Attribute.bold.key]
            ?.value,
        isTrue,
      );
      final bold = tester.widget<IconButton>(
        find.descendant(
          of: find.byTooltip('加粗'),
          matching: find.byType(IconButton),
        ),
      );
      final ordinary = tester.widget<IconButton>(
        find.descendant(
          of: find.byTooltip('斜体'),
          matching: find.byType(IconButton),
        ),
      );
      expect(
        bold.style!.backgroundColor!.resolve({}),
        isNot(ordinary.style!.backgroundColor!.resolve({})),
      );
      expect(
        tester.getSize(find.byTooltip('加粗')),
        const Size.square(EditorToolbarStyle.buttonSize),
      );
      await tester.ensureVisible(find.byTooltip('清除格式'));
      await tester.tap(find.byTooltip('清除格式'));
      await tester.pumpAndSettle();
      expect(
        editor.quillController.getSelectionStyle().attributes.containsKey(
          quill.Attribute.bold.key,
        ),
        isFalse,
      );
      await tester.ensureVisible(find.byTooltip('撤销'));
      await tester.tap(find.byTooltip('撤销'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('普通编辑器仍显示路由返回按钮', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ArticleProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: MaterialApp(
          localizationsDelegates:
              quill.FlutterQuillLocalizations.localizationsDelegates,
          supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const EditorPage()),
                ),
                child: const Text('编辑'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(EditorPage), findsNothing);
  });
}
