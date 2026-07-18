import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/services/app_release_service.dart';
import 'package:storm_teleprompter_plus/widgets/common/startup_update_checker.dart';

void main() {
  const release = GitHubReleaseInfo(
    tagName: 'v2.0.0',
    name: 'Version 2.0.0',
    pageUrl: '$githubRepositoryUrl/releases/tag/v2.0.0',
    notes: '更新内容',
  );
  const update = UpdateCheckResult(
    currentVersion: 'v1.0.0',
    latestRelease: release,
    hasUpdate: true,
    canCompare: true,
  );

  Widget buildChecker({
    required AppUpdateChecker checker,
    String? ignoredVersion,
    IgnoredUpdateSaver? ignoredVersionSaver,
  }) {
    return MaterialApp(
      home: StartupUpdateChecker(
        versionLoader: () async => const AppVersionInfo('v1.0.0'),
        updateChecker: checker,
        ignoredVersionLoader: () async => ignoredVersion,
        ignoredVersionSaver: ignoredVersionSaver,
        child: const Scaffold(body: Text('主页')),
      ),
    );
  }

  testWidgets('shows an update prompt and can ignore this update', (
    tester,
  ) async {
    String? savedVersion;
    await tester.pumpWidget(
      buildChecker(
        checker: (_) async => update,
        ignoredVersionSaver: (version) async => savedVersion = version,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发现新版本 v2.0.0'), findsOneWidget);
    expect(find.text('忽略本次更新'), findsOneWidget);
    expect(find.text('稍后更新'), findsOneWidget);
    expect(find.text('前往更新'), findsOneWidget);

    await tester.tap(find.text('忽略本次更新'));
    await tester.pumpAndSettle();

    expect(savedVersion, 'v2.0.0');
    expect(find.text('发现新版本 v2.0.0'), findsNothing);
  });

  testWidgets('later closes the prompt without ignoring the version', (
    tester,
  ) async {
    var saveCalled = false;
    await tester.pumpWidget(
      buildChecker(
        checker: (_) async => update,
        ignoredVersionSaver: (_) async => saveCalled = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('稍后更新'));
    await tester.pumpAndSettle();

    expect(saveCalled, isFalse);
    expect(find.text('发现新版本 v2.0.0'), findsNothing);
  });

  testWidgets('does not prompt for an ignored release', (tester) async {
    await tester.pumpWidget(
      buildChecker(checker: (_) async => update, ignoredVersion: 'v2.0.0'),
    );
    await tester.pumpAndSettle();

    expect(find.text('主页'), findsOneWidget);
    expect(find.text('发现新版本 v2.0.0'), findsNothing);
  });

  testWidgets('update check errors remain silent', (tester) async {
    await tester.pumpWidget(
      buildChecker(checker: (_) async => throw StateError('network error')),
    );
    await tester.pumpAndSettle();

    expect(find.text('主页'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
