import 'package:hive/hive.dart';

part 'post.g.dart';

@HiveType(typeId: 0)
class Comment {
  @HiveField(0)
  final String userId;
  @HiveField(1)
  final String username;
  @HiveField(2)
  final String text;
  @HiveField(3)
  final DateTime timestamp;

  Comment({
    required this.userId,
    required this.username,
    required this.text,
    required this.timestamp,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      userId: json["user_id"] ?? "",
      username: json["username"] ?? "",
      text: json["content"] ?? "",
      timestamp: DateTime.parse(json["timestamp"]?.toString() ?? DateTime.now().toIso8601String()).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "user_id": userId,
      "username": username,
      "text": text,
      "timestamp": timestamp.toIso8601String(),
    };
  }
}

@HiveType(typeId: 1)
class Post {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String authorId;
  @HiveField(2)
  final String authorName;
  @HiveField(3)
  final String? authorPic;
  @HiveField(4)
  final String content;
  @HiveField(5)
  final List<String> mediaUrls;
  @HiveField(6)
  List<String> likes;
  @HiveField(7)
  List<Comment> comments;
  @HiveField(8)
  final DateTime timestamp;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPic,
    required this.content,
    required this.mediaUrls,
    required this.likes,
    required this.comments,
    required this.timestamp,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json["_id"] ?? json["id"] ?? "",
      authorId: json["author_id"] ?? "",
      authorName: json["author_name"] ?? "",
      authorPic: json["author_pic"],
      content: json["content"] ?? "",
      mediaUrls: List<String>.from(json["media_urls"] ?? []),
      likes: List<String>.from(json["likes"] ?? []),
      comments: (json["comments"] as List? ?? [])
          .map((e) => Comment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      timestamp: DateTime.parse(json["timestamp"]?.toString() ?? DateTime.now().toIso8601String()).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "_id": id,
      "author_id": authorId,
      "author_name": authorName,
      "author_pic": authorPic,
      "content": content,
      "media_urls": mediaUrls,
      "likes": likes,
      "comments": comments.map((c) => c.toJson()).toList(),
      "timestamp": timestamp.toIso8601String(),
    };
  }
}
