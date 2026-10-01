import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/models/app_settings.dart';
import 'package:storm_teleprompter_plus/pages/editor_page.dart';
import 'package:storm_teleprompter_plus/theme/app_colors.dart';
import 'package:storm_teleprompter_plus/utils/constants.dart';
import 'package:storm_teleprompter_plus/widgets/editor/editor_toolbar.dart';
import 'package:storm_teleprompter_plus/widgets/editor/editor_toolbar_style.dart';
import 'support/quick_workspace_test_host.dart';

/// 快速编辑器的模式文案、加宽字号输入及应用主题验证。
void main() {
  testWidgets('字号输入加宽且与按钮等高，仍支持任意像素数值', (tester) async {
    await mountQuickWorkspace(
      tester,
      const EditorPage(quickMode: true, autoSave: false),
      QuickTestArticles(),
      QuickTestSettings(),
    );
    final field = find.descendant(
      of: find.byType(EditorToolbar),
      matching: find.byType(TextField),
    );
    expect(
      tester.getSize(field),
      const Size(
        EditorToolbarStyle.fontSizeInputWidth,
        EditorToolbarStyle.buttonSize,
      ),
    );
    expect(
      tester.getSize(field).width,
      greaterThan(EditorToolbarStyle.buttonSize),
    );
    expect(tester.widget<TextField>(field).decoration!.suffixText, isNull);
    expect(
      tester.renderObject<RenderParagraph>(find.text('字号')).didExceedMaxLines,
      isFalse,
    );
    final editor = quickEditor(tester);
    editor.quillController.replaceText(
      0,
      0,
      '字号测试',
      const TextSelection(baseOffset: 0, extentOffset: 4),
    );
    await tester.pump();
    await tester.enterText(field, '128.5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      editor.quillController
          .getSelectionStyle()
          .attributes[quill.Attribute.size.key]
          ?.value,
      128.5,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('快速模式标题不随保存变化，确认弹窗标明临时稿件及当前标题', (tester) async {
    final articles = QuickTestArticles();
    await mountQuickWorkspace(
      tester,
      const EditorPage(quickMode: true, autoSave: false),
      articles,
      QuickTestSettings(),
    );
    const title = '${AppConstants.displayName}：快速模式';
    expect(find.text(title), findsOneWidget);
    expect(find.text('新建稿件'), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    await tester.enterText(find.byType(TextField).first, '直播开场稿');
    final editor = quickEditor(tester);
    final leave = editor.confirmLeave();
    await tester.pumpAndSettle();
    expect(find.text('保存临时稿件？'), findsOneWidget);
    expect(find.text('临时稿件“直播开场稿”尚未保存。'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await leave, isFalse);
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('根目录'));
    await tester.pumpAndSettle();
    expect(articles.articles.single.title, '直播开场稿');
    expect(find.text(title), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '修改后的标题');
    final leaveAgain = editor.confirmLeave();
    await tester.pumpAndSettle();
    expect(find.text('临时稿件“修改后的标题”尚未保存。'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await leaveAgain, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('窄屏可完整显示快速模式标题与保存操作', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mountQuickWorkspace(
      tester,
      const EditorPage(quickMode: true, autoSave: false),
      QuickTestArticles(),
      QuickTestSettings(),
    );
    final title = find.text('${AppConstants.displayName}：快速模式');
    final button = find.byTooltip('保存');
    expect(
      tester.getBottomLeft(title).dy,
      lessThan(tester.getTopLeft(button).dy),
    );
    expect(tester.getSize(title).width, greaterThan(200));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('编辑器、工具栏和文件夹按钮随深浅色切换，播放配色保持独立', (tester) async {
    final settings = QuickTestSettings();
    final editorPage = EditorPage(
      quickMode: true,
      autoSave: false,
      onOpenLibrary: () {},
    );
    await mountQuickWorkspace(
      tester,
      editorPage,
      QuickTestArticles(),
      settings,
    );
    final editorState = quickEditor(tester);
    final darkButton = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    final darkBackground = darkButton.backgroundColor!;
    expect(darkButton.foregroundColor, AppColors.textPrimary);
    final darkConfig = tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
        .config;
    expect(darkConfig.customStyles!.color, AppColors.textPrimary);
    await settings.setAppBrightnessMode(AppBrightnessMode.light);
    await tester.pumpAndSettle();
    expect(quickEditor(tester), same(editorState));
    final toolbarContext = tester.element(find.byType(EditorToolbar));
    final lightConfig = tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
        .config;
    expect(
      lightConfig.customStyles!.color,
      AppColors.textPrimaryFor(toolbarContext),
    );
    expect(Theme.of(toolbarContext).brightness, Brightness.light);
    final lightButton = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(
      lightButton.backgroundColor!.computeLuminance(),
      greaterThan(darkBackground.computeLuminance()),
    );
    expect(
      lightButton.foregroundColor,
      AppColors.textPrimaryFor(toolbarContext),
    );
    final normalButton = tester.widget<IconButton>(
      find
          .descendant(
            of: find.byType(EditorToolbar),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(
      normalButton.style!.foregroundColor!.resolve({}),
      AppColors.textSecondaryFor(toolbarContext),
    );
    expect(settings.settings.teleprompterBgColor, 0xFF000000);
    expect(settings.settings.textColor, 0);
    await settings.setAppBrightnessMode(AppBrightnessMode.dark);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .backgroundColor,
      darkBackground,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('跟随系统亮暗模式时同步更新编辑器而不改变草稿', (tester) async {
    final settings = QuickTestSettings();
    await settings.setAppBrightnessMode(AppBrightnessMode.system);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await mountQuickWorkspace(
      tester,
      EditorPage(quickMode: true, autoSave: false, onOpenLibrary: () {}),
      QuickTestArticles(),
      settings,
    );
    final editor = quickEditor(tester);
    editor.titleController.text = '系统主题测试';
    await tester.pump();
    final lightButton = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(
      Theme.of(tester.element(find.byType(EditorToolbar))).brightness,
      Brightness.light,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(EditorToolbar))).brightness,
      Brightness.dark,
    );
    expect(quickEditor(tester), same(editor));
    expect(editor.titleController.text, '系统主题测试');
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .backgroundColor,
      isNot(lightButton.backgroundColor),
    );
    await tester.pumpWidget(const SizedBox());
  });
}
