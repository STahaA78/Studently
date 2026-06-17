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

class UserProfileResponse {
  final bool exists;
  final User? data;

  UserProfileResponse({required this.exists, this.data});

  factory UserProfileResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return UserProfileResponse(
      exists: json['exists'] ?? false,
      data: rawData is Map<String, dynamic> ? User.fromJson(rawData) : null,
    );
  }
}

class User {
  final String id;
  String name;
  final String email;
  int? friendsCount;
  int? postsCount;
  int? resourcesCount;
  String? password;
  String? birthday; // MM/DD/YYYY
  Department? department;
  String? batch;
  Campus? campus;
  Gender? gender;
  List<Interest> interests;
  String? university;
  String? picture; // Cloudflare R2 URL
  String? thumbnail; // Discover card background URL
  bool isPrivate;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.friendsCount,
    this.postsCount,
    this.resourcesCount,
    this.password,
    this.birthday,
    this.department,
    this.batch,
    this.campus,
    this.gender,
    List<Interest>? interests,
    this.university,
    this.picture,
    this.thumbnail,
    this.isPrivate = false,
  }) : interests = interests ?? [];

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      friendsCount: json['friends_count'] ?? 0,
      postsCount: json['posts_count'] ?? 0,
      resourcesCount: json['resources_count'] ?? 0,
      password: json['password'],
      birthday: json['birthday'],
      department: json['department'] != null
          ? Department.fromJson(json['department'])
          : null,
      batch: json['batch'],
      campus: json['campus'] != null ? Campus.fromJson(json['campus']) : null,
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
      thumbnail: json['thumbnail'] ?? '',
      isPrivate: json['is_private'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'friendsCount': friendsCount,
      'postsCount': postsCount,
      'resourcesCount': resourcesCount,
      'password': password,
      'birthday': birthday,
      'department': department?.toJson(),
      'batch': batch,
      'campus': campus?.toJson(),
      'gender': gender?.toApiString(),
      'university': university,
      'picture': picture,
      'thumbnail': thumbnail,
      'interests': interests.map((i) => i.toJson()).toList(),
      'is_private': isPrivate,
    };
  }
}
