/// Model for storing chat information data
/// Used for displaying chat details in the info page

class ChatInfoData {
  // For DM chats - Other user's information
  String? otherUserId;
  String? otherUserName;
  String? otherUserPicture;
  String? otherUserDepartment;
  String? otherUserBatch;
  String? otherUserBio;

  // Conversation details
  DateTime? conversationStartedAt;
  int? totalMessages;
  DateTime? lastMessageTime;

  // For group chats - Participants information
  List<ParticipantInfo>? participants;
  int? participantCount;
  String? groupName;
  String? groupDescription;
  String? groupImage;
  bool? isUserAdmin;

  // Notifications
  bool? isMuted;

  ChatInfoData({
    this.otherUserId,
    this.otherUserName,
    this.otherUserPicture,
    this.otherUserDepartment,
    this.otherUserBatch,
    this.otherUserBio,
    this.conversationStartedAt,
    this.totalMessages,
    this.lastMessageTime,
    this.participants,
    this.participantCount,
    this.groupName,
    this.groupDescription,
    this.groupImage,
    this.isUserAdmin,
    this.isMuted,
  });

  factory ChatInfoData.fromJson(Map<String, dynamic> json) {
    return ChatInfoData(
      otherUserId: json['other_user_id'],
      otherUserName: json['other_user_name'],
      otherUserPicture: json['other_user_picture'],
      otherUserDepartment: json['other_user_department'],
      otherUserBatch: json['other_user_batch'],
      otherUserBio: json['other_user_bio'],
      conversationStartedAt: json['conversation_started_at'] != null
          ? DateTime.tryParse(json['conversation_started_at'])
          : null,
      totalMessages: json['total_messages'],
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.tryParse(json['last_message_time'])
          : null,
      participants: json['participants'] != null
          ? (json['participants'] as List<dynamic>)
              .map((p) => ParticipantInfo.fromJson(p))
              .toList()
          : null,
      participantCount: json['participant_count'],
      groupName: json['group_name'],
      groupDescription: json['group_description'],
      groupImage: json['group_image'],
      isUserAdmin: json['is_user_admin'],
      isMuted: json['is_muted'],
    );
  }

  Map<String, dynamic> toJson() => {
        'other_user_id': otherUserId,
        'other_user_name': otherUserName,
        'other_user_picture': otherUserPicture,
        'other_user_department': otherUserDepartment,
        'other_user_batch': otherUserBatch,
        'other_user_bio': otherUserBio,
        'conversation_started_at': conversationStartedAt?.toIso8601String(),
        'total_messages': totalMessages,
        'last_message_time': lastMessageTime?.toIso8601String(),
        'participants': participants?.map((p) => p.toJson()).toList(),
        'participant_count': participantCount,
        'group_name': groupName,
        'group_description': groupDescription,
        'group_image': groupImage,
        'is_user_admin': isUserAdmin,
        'is_muted': isMuted,
      };
}

class ParticipantInfo {
  String id;
  String name;
  String picture;
  String role; // "admin", "member"
  DateTime? joinedAt;

  ParticipantInfo({
    required this.id,
    required this.name,
    required this.picture,
    this.role = "member",
    this.joinedAt,
  });

  factory ParticipantInfo.fromJson(Map<String, dynamic> json) {
    return ParticipantInfo(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      picture: json['picture'] ?? '',
      role: json['role'] ?? 'member',
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'picture': picture,
        'role': role,
        'joined_at': joinedAt?.toIso8601String(),
      };
}
