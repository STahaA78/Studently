class Course {
  final String code;
  final String name;

  Course({required this.code, required this.name});

  // Factory to convert JSON Map into a Course Object
  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      code: json['course_code'] ?? json['code'] ?? '', 
      name: json['course_name'] ?? json['name'] ?? '',
    );
  }
}