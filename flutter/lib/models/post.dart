class Comment {
  final String userId;
  final String username;
  final String text;
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
      timestamp: DateTime.parse(json["timestamp"].toString()).toLocal(),
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

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPic;
  final String content;
  final List<String> mediaUrls;
  List<String> likes;
  List<Comment> comments;
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
      id: json["_id"],
      authorId: json["author_id"],
      authorName: json["author_name"],
      authorPic: json["author_pic"],
      content: json["content"],
      mediaUrls: List<String>.from(json["media_urls"] ?? []),
      likes: List<String>.from(json["likes"] ?? []),
      comments: (json["comments"] as List? ?? [])
          .map((e) => Comment.fromJson(e))
          .toList(),
      timestamp: DateTime.parse(json["timestamp"].toString()).toLocal(),
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