import 'app_settings.dart';
import 'article.dart';
import 'folder.dart';

/// 应用完整备份的数据模型。
///
/// 备份包含服务端持久化的全部稿件、文件夹层级和应用设置。
/// [format] 与 [version] 用于在恢复前识别文件并控制后续格式升级。
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

  /// 解析并完整校验备份数据。
  ///
  /// 所有数据会先构造完成，调用方确认解析成功后再写入存储，避免无效文件
  /// 导致只恢复了一部分内容。
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
