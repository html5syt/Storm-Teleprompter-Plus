import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/widgets/teleprompter/prompt_entrance.dart';

/// 验证真实几何位移和缓出速度，而不是仅检查动画组件的类型。
void main() {
  testWidgets('正文从底部先快后慢滑入，刷新内容不重播', (tester) async {
    const key = ValueKey('正文');
    Widget page(String text) => MaterialApp(
      home: Scaffold(
        body: PromptEntrance(
          child: SizedBox.expand(key: key, child: Text(text)),
        ),
      ),
    );
    await tester.pumpWidget(page('正文'));
    final height = tester.getSize(find.byType(Scaffold)).height;
    final initial = tester.getTopLeft(find.byKey(key)).dy;
    expect(initial, height);
    await tester.pump(const Duration(milliseconds: 150));
    final first = tester.getTopLeft(find.byKey(key)).dy;
    await tester.pump(const Duration(milliseconds: 150));
    final second = tester.getTopLeft(find.byKey(key)).dy;
    expect(initial - first, greaterThan(first - second));
    expect(second, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.getTopLeft(find.byKey(key)).dy, 0);
    await tester.pumpWidget(page('刷新正文'));
    expect(tester.getTopLeft(find.byKey(key)).dy, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('系统减少动画时正文直接到达原位', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: PromptEntrance(child: SizedBox.expand(key: ValueKey('正文'))),
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(const ValueKey('正文'))).dy, 0);
  });
}
