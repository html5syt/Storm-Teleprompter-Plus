import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// 工程及发布入口只声明原生平台，防止后续脚手架更新重新引入 Web 构建。
void main() {
  test('移除 Web 工程、工作流和图标生成目标，保留五个原生平台', () {
    expect(Directory('web').existsSync(), isFalse);
    final metadata = File('.metadata').readAsStringSync();
    expect(metadata, isNot(contains('platform: web')));
    for (final platform in ['android', 'ios', 'windows', 'macos', 'linux']) {
      expect(Directory(platform).existsSync(), isTrue);
      expect(metadata, contains('platform: $platform'));
    }
    for (final workflow in ['debug', 'release']) {
      final content = File(
        '.github/workflows/$workflow.yml',
      ).readAsStringSync();
      expect(content, isNot(contains('flutter build web')));
      expect(content, isNot(contains('name: Web')));
    }
    expect(
      File('flutter_launcher_icons.yaml').readAsStringSync(),
      isNot(contains('  web:')),
    );
    expect(
      File('tool/generate_icons.ps1').readAsStringSync(),
      isNot(contains('iOS, Web,')),
    );
  });
}
