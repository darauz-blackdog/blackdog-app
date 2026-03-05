class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // order, promo, stock, general
  final bool read;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'general',
    this.read = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String? ?? 'general',
      read: json['read'] as bool? ?? false,
      createdAt: json['created_at'] as String,
    );
  }

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      read: read ?? this.read,
      createdAt: createdAt,
    );
  }
}
