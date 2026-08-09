import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  const entitlementFiles = [
    'macos/Runner/DebugProfile.entitlements',
    'macos/Runner/Release.entitlements',
  ];

  test('macOS builds can access files and folders selected by the user', () {
    for (final relativePath in entitlementFiles) {
      final content = File(relativePath).readAsStringSync();
      final document = XmlDocument.parse(content);
      final entries = document
          .findAllElements('dict')
          .first
          .children
          .whereType<XmlElement>()
          .toList();
      final entitlementIndex = entries.indexWhere(
        (element) =>
            element.name.local == 'key' &&
            element.innerText ==
                'com.apple.security.files.user-selected.read-write',
      );

      expect(
        entitlementIndex,
        isNot(-1),
        reason:
            '$relativePath must support file_selector open and save panels.',
      );
      expect(
        entitlementIndex == -1
            ? null
            : entries[entitlementIndex + 1].name.local,
        'true',
        reason: '$relativePath must enable file-selector access.',
      );
    }
  });
}
