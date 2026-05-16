class Comment {
  final String userId;
  final String username;
  final String? picture;
  final String text;
  final DateTime timestamp;

  Comment({
    required this.userId,
    required this.username,
    this.picture,
    required this.text,
    required this.timestamp,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      userId: json["user_id"] ?? "",
      username: json["username"] ?? "",
      picture: json["picture"]?.toString(),
      // Support both payload shapes:
      // - backend/API: "content"
      // - legacy local cache: "text"
      text: (json["content"] ?? json["text"] ?? "").toString(),
      timestamp: DateTime.parse(json["timestamp"].toString()).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "user_id": userId,
      "username": username,
      "picture": picture,
      // Keep cache shape aligned with backend/API contract.
      "content": text,
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
  final String? mediaUrl;
  final double? mediaAspectRatio;
  final List<String> likes;
  final List<Comment> comments;
  final DateTime timestamp;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPic,
    required this.content,
    this.mediaUrl,
    this.mediaAspectRatio,
    required this.likes,
    required this.comments,
    required this.timestamp,
  });

  Post copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorPic,
    String? content,
    String? mediaUrl,
    double? mediaAspectRatio,
    List<String>? likes,
    List<Comment>? comments,
    DateTime? timestamp,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorPic: authorPic ?? this.authorPic,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaAspectRatio: mediaAspectRatio ?? this.mediaAspectRatio,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json["_id"],
      authorId: json["author_id"],
      authorName: json["author_name"],
      authorPic: json["author_pic"],
      content: json["content"],
      mediaUrl: json["media_url"],
      mediaAspectRatio: json["media_aspect_ratio"] != null
          ? (json["media_aspect_ratio"] as num).toDouble()
          : null,
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
      "media_url": mediaUrl,
      "media_aspect_ratio": mediaAspectRatio,
      "likes": likes,
      "comments": comments.map((c) => c.toJson()).toList(),
      "timestamp": timestamp.toIso8601String(),
    };
  }
}
