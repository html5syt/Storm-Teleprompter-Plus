import 'dart:convert';
import 'dart:io';

void main() {
  final data = jsonDecode(
    File('notes/Storm Teleprompter Plus/content.json').readAsStringSync(),
  );

  void printTopic(Map<String, dynamic> topic, int depth) {
    final title = topic['title'] ?? '';
    final indent = '  ' * depth;
    if (title.isNotEmpty) {
      print('$indent- $title');
    }
    final children = topic['children']?['attached'] as List?;
    if (children != null) {
      for (final child in children) {
        printTopic(child as Map<String, dynamic>, depth + 1);
      }
    }
  }

  final sheets = data as List;
  for (final sheet in sheets) {
    final rootTopic = sheet['rootTopic'] as Map<String, dynamic>;
    printTopic(rootTopic, 0);
  }
}
