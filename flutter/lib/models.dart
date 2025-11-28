class User {
  String fullName;
  String email;
  String password;
  DateTime? birthdate;
  String? department;
  String? batch;
  List<String>? interests;

  User({
    required this.fullName,
    required this.email,
    required this.password
  });
}
