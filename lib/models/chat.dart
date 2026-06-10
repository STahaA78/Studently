import 'package:studently/services/firebase_auth.dart';

class ChatMessage {
  String id;
  String conversationId;
  String senderId;
  String senderName; // NEW: Added senderName
  String text;
  List<String> attachments = [];
  String timestamp;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName, // NEW
    required this.text,
    List<String>? attachments,
    required this.timestamp,
  }) {
    if (attachments != null) this.attachments = attachments;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'] ?? '',
      conversationId: json['conversation_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      senderName: json['sender_name'] ?? 'Unknown', // NEW
      text: json['text'] ?? '',
      attachments: List<String>.from(json['attachments'] ?? []),
      timestamp: json['timestamp'] ?? '',
    );
  }
  Map<String, dynamic> toJson() => {
    '_id': id,
    'conversation_id': conversationId,
    'sender_id': senderId,
    'sender_name': senderName,
    'text': text,
    'attachments': attachments,
    'timestamp': timestamp,
  };
  bool get isMe => senderId == authService.value.currentUser?.uid;
}

class ChatConversation {
  String id;
  List<String> participants = [];
  Map<String, dynamic>? lastMessage;
  Map<String, int> unreadCounts = {};
  String createdAt;

  // NEW FIELDS FOR GROUP CHATS
  bool isGroup;
  String? courseId;
  String? title;

  // NEW FIELDS FOR SOFT DELETE
  List<String> deletedForUsers = []; // Users who have deleted this chat

  ChatConversation({
    required this.id,
    List<String>? participants,
    this.lastMessage,
    Map<String, int>? unreadCounts,
    required this.createdAt,
    this.isGroup = false,
    this.courseId,
    this.title,
    List<String>? deletedForUsers,
  }) {
    if (participants != null) this.participants = participants;
    if (unreadCounts != null) this.unreadCounts = unreadCounts;
    if (deletedForUsers != null) this.deletedForUsers = deletedForUsers;
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    Map<String, int> parsedCounts = {};
    if (json['unread_counts'] != null) {
      (json['unread_counts'] as Map<String, dynamic>).forEach((key, value) {
        parsedCounts[key] = value as int;
      });
    }

    return ChatConversation(
      id: json['_id'] ?? '',
      participants: List<String>.from(json['participants'] ?? []),
      lastMessage: json['last_message'],
      unreadCounts: parsedCounts,
      createdAt: json['created_at'] ?? '',
      isGroup: json['is_group'] ?? false,
      courseId: json['course_id'],
      title: json['title'],
      deletedForUsers: List<String>.from(json['deleted_for_users'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'participants': participants,
    'last_message': lastMessage,
    'unread_counts': unreadCounts,
    'created_at': createdAt,
    'is_group': isGroup,
    'course_id': courseId,
    'title': title,
    'deleted_for_users': deletedForUsers,
  };

  ChatConversation copyWith({
    String? id,
    List<String>? participants,
    Map<String, dynamic>? lastMessage,
    Map<String, int>? unreadCounts,
    String? createdAt,
    bool? isGroup,
    String? courseId,
    String? title,
    List<String>? deletedForUsers,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      createdAt: createdAt ?? this.createdAt,
      isGroup: isGroup ?? this.isGroup,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      deletedForUsers: deletedForUsers ?? this.deletedForUsers,
    );
  }
}
