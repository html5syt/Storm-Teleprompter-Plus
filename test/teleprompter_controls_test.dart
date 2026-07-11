import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/models/app_settings.dart';
import 'package:storm_teleprompter_plus/providers/teleprompter_provider.dart';

void main() {
  testWidgets('pinned overlays ignore auto-hide until unpinned', (
    tester,
  ) async {
    const settings = AppSettings(wpm: 0, autoHideDelaySeconds: 1);
    final provider = TeleprompterProvider()..loadScript('article', '测试正文');
    void listener() {}

    provider.addListener(listener);
    addTearDown(() {
      provider.removeListener(listener);
      provider.dispose();
    });

    provider.play(settings);
    provider.toggleControlsPinned(settings);
    await tester.pump(const Duration(seconds: 2));

    expect(provider.controlsPinned, isTrue);
    expect(provider.controlsVisible, isTrue);

    provider.toggleControls();
    expect(provider.controlsVisible, isTrue);

    provider.toggleControlsPinned(settings);
    await tester.pump(const Duration(seconds: 2));

    expect(provider.controlsPinned, isFalse);
    expect(provider.controlsVisible, isFalse);
    provider.stopAll();
  });
}
