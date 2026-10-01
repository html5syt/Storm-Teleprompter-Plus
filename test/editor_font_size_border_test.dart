import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/theme/app_colors.dart';
import 'package:storm_teleprompter_plus/theme/app_theme.dart';
import 'package:storm_teleprompter_plus/widgets/editor/editor_toolbar_style.dart';

/// 比较实际绘制边框的容器，而非可能包含空白的 TextField 外层尺寸。
void main() {
  for (final light in [false, true]) {
    for (final density in [VisualDensity.standard, VisualDensity.compact]) {
      testWidgets('字号边框与按钮对齐：浅色=$light，密度=$density', (tester) async {
        final focus = FocusNode();
        final theme =
            (light
                    ? AppTheme.lightFromColorAndFont(AppColors.primary)
                    : AppTheme.darkTheme)
                .copyWith(visualDensity: density);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Builder(
                builder: (context) => Row(
                  children: [
                    SizedBox(
                      width: EditorToolbarStyle.fontSizeInputWidth,
                      height: EditorToolbarStyle.buttonSize,
                      child: TextField(
                        focusNode: focus,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(fontSize: 12),
                        decoration: EditorToolbarStyle.fontSizeDecoration(
                          context,
                        ),
                      ),
                    ),
                    EditorToolbarButton(
                      icon: const Icon(Icons.format_bold),
                      tooltip: '对照按钮',
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final button = find.byType(IconButton);
        final editable = find.byType(EditableText);
        // 同时检查未聚焦、聚焦和输入数字后的真实边框。
        for (final value in ['', '128.5']) {
          if (value.isNotEmpty) {
            await tester.tap(find.byType(TextField));
            await tester.enterText(find.byType(TextField), value);
          }
          await tester.pumpAndSettle();
          final container = InputDecorator.containerOf(
            tester.element(editable),
          )!;
          final rect = container.localToGlobal(Offset.zero) & container.size;
          final buttonRect = tester.getRect(button);
          expect(rect.top, buttonRect.top);
          expect(rect.bottom, buttonRect.bottom);
          expect(
            rect.size,
            const Size(
              EditorToolbarStyle.fontSizeInputWidth,
              EditorToolbarStyle.buttonSize,
            ),
          );
        }
        await tester.pumpWidget(const SizedBox());
        focus.dispose();
      });
    }
  }
}
