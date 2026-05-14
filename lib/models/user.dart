import 'package:studently/models/backend_config.dart';

enum Gender { male, female, other }

extension GenderExtension on Gender {
  String get displayName {
    switch (this) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Other';
    }
  }

  static Gender fromString(String value) {
    switch (value.toLowerCase()) {
      case 'male':
        return Gender.male;
      case 'female':
        return Gender.female;
      case 'other':
        return Gender.other;
      default:
        throw ArgumentError('Invalid gender: $value');
    }
  }

  String toApiString() => displayName;
}

class FriendStatus {
  final String id;
  final String status; // "friends", "incoming_request", "none"

  FriendStatus({required this.id, required this.status});

  factory FriendStatus.fromJson(Map<String, dynamic> json) {
    return FriendStatus(id: json['id'] ?? '', status: json['status'] ?? 'none');
  }
}

class User {
  final String id;
  String name;
  final String email;
  int? friendsCount;
  String? password;
  String? birthday; // MM/DD/YYYY
  Department? department;
  String? batch;
  Gender? gender;
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
    this.gender,
    List<Interest>? interests,
    this.university,
    this.picture,
  }) : interests = interests ?? [];

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      friendsCount: json['friends_count'] ?? 0,
      password: json['password'],
      birthday: json['birthday'],
      department: json['department'] != null
          ? Department.fromJson(json['department'])
          : null,
      batch: json['batch'],
      gender: json['gender'] != null
          ? GenderExtension.fromString(json['gender'])
          : null,
      interests:
          (json['interests'] as List<dynamic>?)
              ?.map((e) => Interest.fromJson(e))
              .toList() ??
          [],
      university: json['university'],
      picture: json['picture'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'friendsCount': friendsCount,
      'password': password,
      'birthday': birthday,
      'department': department?.toJson(),
      'batch': batch,
      'gender': gender?.toApiString(),
      'university': university,
      'picture': picture,
      'interests': interests.map((i) => i.toJson()).toList(),
    };
  }
}
