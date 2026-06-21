/// 稿件数据模型
///
/// 对应原始项目中的 Article 接口，存储提词器稿件信息。
/// 本地使用 JSON 文件持久化，无需后端服务。
class Article {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int sortOrder;
  final Map<String, dynamic>? teleprompterSettings; // 每稿独立的提词器设置
  final String? folderId; // 所属文件夹ID，null表示根目录

  Article({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
    this.teleprompterSettings,
    this.folderId,
  });

  /// 从 JSON 反序列化
  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      sortOrder: json['sortOrder'] as int? ?? 0,
      teleprompterSettings: json['teleprompterSettings'] != null
          ? Map<String, dynamic>.from(json['teleprompterSettings'] as Map)
          : null,
      folderId: json['folderId'] as String?,
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'sortOrder': sortOrder,
      if (teleprompterSettings != null)
        'teleprompterSettings': teleprompterSettings,
      if (folderId != null) 'folderId': folderId,
    };
  }

  /// 创建副本并修改部分字段
  Article copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
    Map<String, dynamic>? teleprompterSettings,
    String? folderId,
    bool clearFolderId = false,
  }) {
    return Article(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      teleprompterSettings: teleprompterSettings ?? this.teleprompterSettings,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
    );
  }

  /// 获取正文预览（前 N 个字符）
  String getPreview({int maxLength = 120}) {
    final plainText = content.trim();
    if (plainText.length <= maxLength) return plainText;
    return '${plainText.substring(0, maxLength)}...';
  }
}
