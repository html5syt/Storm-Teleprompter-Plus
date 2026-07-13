import 'dart:io';

/// 读取开发工作区当前提交的短哈希；发布包或无 Git 环境时返回空。
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
