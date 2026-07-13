import 'dart:io';

/// 删除 Android 文件选择器为流式读取创建的临时缓存副本。
///
/// 其他原生平台返回的是用户选择的原文件路径，不能由应用主动删除。
Future<void> cleanupTemporarySelectedFile(String path) async {
  if (!Platform.isAndroid) return;
  final file = File(path);
  if (await file.exists()) await file.delete();
  final parent = file.parent;
  if (await parent.exists() && await parent.list().isEmpty) {
    await parent.delete();
  }
}
