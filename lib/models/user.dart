import 'package:studently/models/backend_config.dart';

class FriendStatus {
  final String id;
  final String status; // "friends", "incoming_request", "none"

  FriendStatus({
    required this.id,
    required this.status,
  });

  factory FriendStatus.fromJson(Map<String, dynamic> json) {
    return FriendStatus(
      id: json['id'] ?? '',
      status: json['status'] ?? 'none',
    );
  }
}

class User {
  final String id;
  String name;
  final String email;
  int? friendsCount;
  String? password;
  String? birthday; // MM/DD/YYYY
  String? department;
  String? batch;
  List<Interest> interests;
  String? university;
  String? picture; // Cloudflare R2 URL

  User({
    required this.id,
    required this.name,
    required this.email,
    this.friendsCount,
    this.password,
    this.birthday,
    this.department,
    this.batch,
    List<Interest>? interests,
    this.university,
    this.picture,
  }) : interests = interests ?? [];

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      friendsCount: json['friends_count']  ?? 0,
      password: json['password'],
      birthday: json['birthday'],
      department: json['department'],
      batch: json['batch'],
      interests: (json['interests'] as List<dynamic>?)?.map((e) => Interest.fromJson(e)).toList() ?? [],
      university: json['university'],
      picture: json['picture'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'friendsCount': friendsCount, // ADDED
      'password': password,
      'birthday': birthday,
      'department': department,
      'batch': batch,
      'university': university, // ADDED
      'picture': picture, // Cloudflare R2 URL
      'interests': interests.map((i) => i.toJson()).toList(),
    };
  }
}