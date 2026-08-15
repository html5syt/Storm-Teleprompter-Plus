import 'dart:io';

Future<void> cleanupTemporarySelectedFile(String path) async {
  if (!Platform.isAndroid) return;
  final file = File(path);
  if (await file.exists()) await file.delete();
  final parent = file.parent;
  if (await parent.exists() && await parent.list().isEmpty) {
    await parent.delete();
  }
}
