import 'app_settings.dart';
import 'article.dart';
import 'folder.dart';

class AppBackup {
  static const String currentFormat = 'storm-teleprompter-backup';
  static const int currentVersion = 1;

  const AppBackup({
    required this.createdAt,
    required this.articles,
    required this.folders,
    required this.settings,
  });

  final DateTime createdAt;
  final List<Article> articles;
  final List<Folder> folders;
  final AppSettings settings;

  factory AppBackup.fromJson(Map<String, dynamic> json) {
    if (json['format'] != currentFormat || json['version'] != currentVersion) {
      throw const FormatException('不是受支持的飓风提词器备份文件');
    }

    return AppBackup(
      createdAt: DateTime.parse(json['createdAt'] as String),
      articles: (json['articles'] as List<dynamic>)
          .map((item) => Article.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      folders: (json['folders'] as List<dynamic>)
          .map((item) => Folder.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      settings: AppSettings.fromJson(json['settings'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'format': currentFormat,
      'version': currentVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'articles': articles.map((item) => item.toJson()).toList(),
      'folders': folders.map((item) => item.toJson()).toList(),
      'settings': settings.toJson(),
    };
  }
}
