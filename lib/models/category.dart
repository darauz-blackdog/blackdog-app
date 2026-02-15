class Category {
  final int id;
  final String name;
  final int? parentId;
  final String? fullPath;
  final String? icon;
  final int sortOrder;
  final List<Category> children;

  Category({
    required this.id,
    required this.name,
    this.parentId,
    this.fullPath,
    this.icon,
    this.sortOrder = 0,
    this.children = const [],
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
      parentId: json['parent_id'] as int?,
      fullPath: json['full_path'] as String?,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      children: (json['children'] as List? ?? [])
          .map((c) => Category.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
