class User {
  String name; // renamed from fullName
  String email;
  String password;
  String? birthday; // String in MM/DD/YYYY format
  String? department;
  String? batch;
  List<String> interests = [];
  String? university = "FAST";
  String? profilePicture;
  String? bio;

  User({
    required this.name,
    required this.email,
    required this.password,
    this.birthday,
    this.department,
    this.batch,
    List<String>? interests,
    this.university,
    this.profilePicture,
    this.bio,
  }) {
    if (interests != null) this.interests = interests;
  }

  Map<String, dynamic> toJson() => {
        'Name': name,
        'email': email,
        'password': password,
        'birthday': birthday ?? '',
        'department': department ?? '',
        'batch': batch ?? '',
        'interests': interests,
        'university': university ?? 'FAST',
        'profile_picture': profilePicture,
        'bio': bio,
      };
}
