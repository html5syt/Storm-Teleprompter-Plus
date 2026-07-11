import 'dart:io';

Future<String?> readGitCommitHash() async {
  try {
    final result = await Process.run('git', ['rev-parse', '--short=8', 'HEAD']);
    if (result.exitCode != 0) return null;
    final hash = result.stdout.toString().trim();
    return hash.isEmpty ? null : hash;
  } catch (_) {
    return null;
  }
}
