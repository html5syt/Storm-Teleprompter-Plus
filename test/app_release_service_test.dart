import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:storm_teleprompter_plus/services/app_release_service.dart';

void main() {
  test('compares semantic release versions', () {
    expect(isNewerRelease('v2.1.0', 'v2.0.9'), isTrue);
    expect(isNewerRelease('v2.0.0', '2.0.0'), isFalse);
    expect(isNewerRelease('v1.9.9', 'v2.0.0'), isFalse);
    expect(isNewerRelease('latest', 'development'), isFalse);
  });

  test('parses GitHub latest release response', () async {
    final client = MockClient((request) async {
      expect(request.headers['Accept'], 'application/vnd.github+json');
      return http.Response(
        jsonEncode({
          'tag_name': 'v2.2.0',
          'name': 'Version 2.2.0',
          'html_url': '$githubRepositoryUrl/releases/tag/v2.2.0',
          'body': 'Release notes',
        }),
        200,
      );
    });
    final service = AppReleaseService(client: client);
    addTearDown(service.dispose);

    final result = await service.checkForUpdates('v2.1.0');

    expect(result.hasUpdate, isTrue);
    expect(result.canCompare, isTrue);
    expect(result.latestRelease.tagName, 'v2.2.0');
  });
}
