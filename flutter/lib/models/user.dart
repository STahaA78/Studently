class User {
  final String id;
  final String name;
  final String email;
  final String connectionCount;
  final String department;
  final String batch;
  final String? profilePhotoUrl;
  final List<String>? interests;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.connectionCount,
    required this.department,
    required this.batch,
    this.profilePhotoUrl,
    this.interests,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      connectionCount: json['connection_count'] ?? '',
      department: json['department'] ?? '',
      batch: json['batch'] ?? '',
      profilePhotoUrl: json['profile_photo_url'],
      interests: (json['interests'] as List?)?.map((e) => e.toString()).toList(),
    );
  }

  // factory User.fromMap(Map<String, dynamic> map) {
  //   return User(
  //     id: map['id'] ?? '',
  //     name: map['name'] ?? '',
  //     department: map['department'] ?? '',
  //     batch: map['batch'] ?? '',
  //     interests: (map['interests'] as List?)?.map((e) => e.toString()).toList(),
  //   );
  // }

  // Map<String, dynamic> toMap() {
  //   return {
  //     'id': id,
  //     'name': name,
  //     'department': department,
  //     'batch': batch,
  //     'interests': interests,
  //   };
  // }
}