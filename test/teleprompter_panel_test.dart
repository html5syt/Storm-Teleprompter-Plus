import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:storm_teleprompter_plus/providers/settings_provider.dart';
import 'package:storm_teleprompter_plus/providers/teleprompter_provider.dart';
import 'package:storm_teleprompter_plus/widgets/teleprompter/teleprompter_settings_panel.dart';

/// 侧栏只保留进度条显示设置，调速入口统一放在播放工具栏。
void main() {
  testWidgets('播放进度条分组保留显示项和字号，不再提供速度输入', (tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider(create: (_) => TeleprompterProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(body: TeleprompterSettingsPanel(onClose: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('播放进度条'), findsOneWidget);
    expect(find.text('播放与进度'), findsNothing);
    expect(find.byTooltip('应用速度'), findsNothing);
    expect(find.text('字/分'), findsNothing);
    for (final title in ['已用时间', '进度百分比', '滚动速度', '当前时间', '字号比例']) {
      expect(find.text(title), findsOneWidget);
    }
    final speedRow = find
        .ancestor(of: find.text('滚动速度'), matching: find.byType(Row))
        .first;
    await tester.tap(
      find.descendant(of: speedRow, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();
    expect(settings.mergedSettings.progressShowSpeed, isFalse);
    expect(settings.mergedSettings.wpm, 150);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
  });
}
