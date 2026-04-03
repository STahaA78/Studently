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
  String? profilePhotoUrl;
  String? bio;

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
    this.profilePhotoUrl,
    this.bio,
  }) : interests = interests ?? [];

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      friendsCount: json['friendsCount'] ?? 0,
      password: json['password'],
      birthday: json['birthday'],
      department: json['department'],
      batch: json['batch'],
      interests: (json['interests'] as List<dynamic>?)?.map((e) => Interest.fromJson(e)).toList() ?? [],
      university: json['university'],
      profilePhotoUrl: json['profilePhotoUrl'],
      bio: json['bio'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      '_id': id, // Adding this helps if MongoDB expects the ID here
      'name': name,
      'email': email,
      'friendsCount': friendsCount, // ADDED
      'password': password,
      'birthday': birthday,
      'department': department,
      'batch': batch,
      'university': university, // ADDED
      'bio': bio, // ADDED
      'profilePhotoUrl': profilePhotoUrl, // FIXED: Now exactly matches fromJson!
      'interests': interests.map((i) => i.toJson()).toList(),
    };
  }
}