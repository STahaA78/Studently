class ChatMessage {
  String id;
  String conversationId;
  String senderId;
  String receiverId;
  String text;
  List<String> attachments = [];
  String timestamp;
  String status;
  bool isDeleted;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    List<String>? attachments,
    required this.timestamp,
    this.status = 'sent',
    this.isDeleted = false,
  }) {
    if (attachments != null) this.attachments = attachments;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'] ?? '',
      conversationId: json['conversation_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      receiverId: json['receiver_id'] ?? '',
      text: json['text'] ?? '',
      attachments: List<String>.from(json['attachments'] ?? []),
      timestamp: json['timestamp'] ?? '',
      status: json['status'] ?? 'sent',
      isDeleted: json['is_deleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'text': text,
        'attachments': attachments,
        'timestamp': timestamp,
        'status': status,
        'is_deleted': isDeleted,
      };
}

class ChatConversation {
  String id;
  List<String> participants = [];
  Map<String, dynamic>? lastMessage;
  Map<String, int> unreadCounts = {};
  String createdAt;

  ChatConversation({
    required this.id,
    List<String>? participants,
    this.lastMessage,
    Map<String, int>? unreadCounts,
    required this.createdAt,
  }) {
    if (participants != null) this.participants = participants;
    if (unreadCounts != null) this.unreadCounts = unreadCounts;
  }
  // converts json to object
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
    );
  }
 //coverts the object to json
  Map<String, dynamic> toJson() => {
        '_id': id,
        'participants': participants,
        'last_message': lastMessage,
        'unread_counts': unreadCounts,
        'created_at': createdAt,
      };
}