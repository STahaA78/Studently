class User {
  final String id;
  String name;
  final String email;
  int friendsCount;
  String department;
  String batch;
  String profilePhotoUrl;
  List<String> interests;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.friendsCount,
    required this.department,
    required this.batch,
    required this.profilePhotoUrl,
    required this.interests,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      friendsCount: json['friendsCount'] ?? 0,
      department: json['department'] ?? '',
      batch: json['batch'] ?? '',
      profilePhotoUrl: json['profilePhotoUrl'] ?? '',
      interests: List<String>.from(json['interests'] ?? []),
    );
  }
}