/// 文件夹数据模型
///
/// 用于稿件分类管理，支持多级子文件夹。
class Folder {
  final String id;
  final String name;
  final String? parentId; // null = 根目录
  final DateTime createdAt;
  final int sortOrder;

  Folder({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
    this.sortOrder = 0,
  });

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: json['parentId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
      'createdAt': createdAt.toIso8601String(),
      'sortOrder': sortOrder,
    };
  }

  Folder copyWith({
    String? id,
    String? name,
    String? parentId,
    DateTime? createdAt,
    int? sortOrder,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
