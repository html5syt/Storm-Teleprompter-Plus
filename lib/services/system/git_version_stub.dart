/// 不支持本地进程的平台无法读取 Git 提交信息。
Future<String?> readGitCommitHash() async => null;
