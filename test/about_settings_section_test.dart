import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/services/app_release_service.dart';
import 'package:storm_teleprompter_plus/widgets/settings/about_settings_section.dart';

void main() {
  test('local development version resolves to the Git commit hash', () async {
    final version = await AppVersionInfo.load();

    expect(version.value, matches(RegExp(r'^[0-9a-f]{8}$')));
  });

  testWidgets('about section exposes help, updates, and the bundled license', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AboutSettingsSection(
              versionLoader: () async => const AppVersionInfo('1234abcd'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('帮助'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('License'), findsOneWidget);
    expect(find.textContaining('版本 1234abcd'), findsNWidgets(2));

    await tester.tap(find.text('License'));
    await tester.pumpAndSettle();

    expect(find.text('MIT License'), findsWidgets);
    expect(find.textContaining('Copyright (c) 2026 Html5syt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
