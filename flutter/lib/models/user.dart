import 'package:studently/models/backend_config.dart';

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
}