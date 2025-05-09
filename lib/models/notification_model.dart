class NotificationModel {
  final String id;
  final String title;
  final String description;
  final String senderName;
  final String senderRole;
  final String createdAt;
  final String type;
  final bool isCompleted;

  NotificationModel({
    required this.id,
    required this.title,
    required this.description,
    required this.senderName,
    required this.senderRole,
    required this.createdAt,
    required this.type,
    this.isCompleted = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      senderName: json['sender_name'],
      senderRole: json['sender_role'],
      createdAt: json['created_at'] ?? '',
      type: json['type'],
      isCompleted: json['is_completed'] ?? false,
    );
  }
} 