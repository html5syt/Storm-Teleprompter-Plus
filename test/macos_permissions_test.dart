import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:storm_teleprompter_plus/main.dart';

Map<String, String> _plistEntries(String relativePath) {
  final document = XmlDocument.parse(File(relativePath).readAsStringSync());
  final dictionary = document.findAllElements('dict').single;
  final elements = dictionary.childElements.toList(growable: false);
  final entries = <String, String>{};

  for (var index = 0; index < elements.length - 1; index++) {
    if (elements[index].name.local != 'key') continue;
    entries[elements[index].innerText] = elements[index + 1].name.local;
  }
  return entries;
}

void main() {
  test('macOS sandbox profiles declare every protected capability in use', () {
    const requiredEntitlements = [
      'com.apple.security.app-sandbox',
      'com.apple.security.files.user-selected.read-write',
      'com.apple.security.network.server',
      'com.apple.security.network.client',
      'com.apple.security.device.audio-input',
      'com.apple.security.device.microphone',
      'com.apple.security.personal-information.photos-library',
    ];

    for (final profile in [
      'macos/Runner/DebugProfile.entitlements',
      'macos/Runner/Release.entitlements',
    ]) {
      final entries = _plistEntries(profile);
      for (final entitlement in requiredEntitlements) {
        expect(entries[entitlement], 'true', reason: '$profile: $entitlement');
      }
    }
  });

  test('macOS privacy declarations explain each protected resource in use', () {
    final document = XmlDocument.parse(
      File('macos/Runner/Info.plist').readAsStringSync(),
    );
    final dictionary = document.findAllElements('dict').single;
    final elements = dictionary.childElements.toList(growable: false);
    final entries = <String, String>{};

    for (var index = 0; index < elements.length - 1; index++) {
      if (elements[index].name.local != 'key') continue;
      entries[elements[index].innerText] = elements[index + 1].innerText;
    }

    for (final key in [
      'NSLocalNetworkUsageDescription',
      'NSMicrophoneUsageDescription',
      'NSPhotoLibraryUsageDescription',
      'NSPhotoLibraryAddUsageDescription',
    ]) {
      expect(entries[key]?.trim(), isNotEmpty, reason: key);
    }
  });

  testWidgets(
    'startup failures render an actionable error instead of a blank window',
    (tester) async {
      await tester.pumpWidget(
        const StartupFailureApp(error: 'SocketException'),
      );

      expect(find.text('无法启动本地服务'), findsOneWidget);
      expect(find.text('SocketException'), findsOneWidget);
    },
  );
}
