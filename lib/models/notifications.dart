import 'package:hive/hive.dart';

part 'notifications.g.dart';

// Make sure typeId is unique! If you have other Hive models (like User=0, Post=1), 
// adjust this number so it doesn't clash with existing typeIds. Let's use 10 to be safe.
@HiveType(typeId: 10) 
class AppNotification {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String recipientId;

  @HiveField(2)
  final String actorId;

  @HiveField(3)
  final String type; // "POST_LIKE", "NEW_COMMENT", "NEW_MESSAGE", etc.

  @HiveField(4)
  final String entityId;

  @HiveField(5)
  final String message;

  @HiveField(6)
  bool isRead;

  @HiveField(7)
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.type,
    required this.entityId,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  // Convert from FastAPI JSON to Dart Object
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id'] ?? json['id'] ?? '',
      recipientId: json['recipient_id'] ?? '',
      actorId: json['actor_id'] ?? '',
      type: json['type'] ?? '',
      entityId: json['entity_id'] ?? '',
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']).toLocal() 
          : DateTime.now(),
    );
  }

  // Convert Dart Object to JSON (useful if we need to cache as JSON or send back)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipient_id': recipientId,
      'actor_id': actorId,
      'type': type,
      'entity_id': entityId,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}