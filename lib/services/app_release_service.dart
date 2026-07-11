import 'dart:convert';

import 'package:http/http.dart' as http;

import 'git_version.dart';

const githubRepositoryUrl =
    'https://github.com/html5syt/Storm-Teleprompter-Plus';
const _latestReleaseApiUrl =
    'https://api.github.com/repos/html5syt/Storm-Teleprompter-Plus/releases/latest';

class AppVersionInfo {
  const AppVersionInfo(this.value);

  final String value;

  bool get isRelease => _parseSemanticVersion(value) != null;

  static Future<AppVersionInfo> load() async {
    const injected = String.fromEnvironment('APP_VERSION');
    if (injected.isNotEmpty) return const AppVersionInfo(injected);
    final hash = await readGitCommitHash();
    return AppVersionInfo(hash ?? 'development');
  }
}

class GitHubReleaseInfo {
  const GitHubReleaseInfo({
    required this.tagName,
    required this.name,
    required this.pageUrl,
    required this.notes,
  });

  final String tagName;
  final String name;
  final String pageUrl;
  final String notes;
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.latestRelease,
    required this.hasUpdate,
    required this.canCompare,
  });

  final String currentVersion;
  final GitHubReleaseInfo latestRelease;
  final bool hasUpdate;
  final bool canCompare;
}

class AppReleaseService {
  AppReleaseService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<UpdateCheckResult> checkForUpdates(String currentVersion) async {
    final response = await _client.get(
      Uri.parse(_latestReleaseApiUrl),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );
    if (response.statusCode != 200) {
      throw StateError('GitHub Release 请求失败：HTTP ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final release = GitHubReleaseInfo(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pageUrl: json['html_url'] as String? ?? githubRepositoryUrl,
      notes: json['body'] as String? ?? '',
    );
    if (release.tagName.isEmpty) throw StateError('Release 版本信息无效');

    final current = _parseSemanticVersion(currentVersion);
    final latest = _parseSemanticVersion(release.tagName);
    return UpdateCheckResult(
      currentVersion: currentVersion,
      latestRelease: release,
      canCompare: current != null && latest != null,
      hasUpdate:
          current != null && latest != null && _compare(latest, current) > 0,
    );
  }

  void dispose() => _client.close();
}

List<int>? _parseSemanticVersion(String value) {
  final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$').firstMatch(value);
  if (match == null) return null;
  return [
    for (var index = 1; index <= 3; index++) int.parse(match.group(index)!),
  ];
}

int _compare(List<int> left, List<int> right) {
  for (var index = 0; index < 3; index++) {
    final result = left[index].compareTo(right[index]);
    if (result != 0) return result;
  }
  return 0;
}

bool isNewerRelease(String latest, String current) {
  final latestVersion = _parseSemanticVersion(latest);
  final currentVersion = _parseSemanticVersion(current);
  return latestVersion != null &&
      currentVersion != null &&
      _compare(latestVersion, currentVersion) > 0;
}
