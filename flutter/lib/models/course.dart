class Course {
  final String code;
  final String name;

  Course({required this.code, required this.name});

  // Factory to convert JSON Map into a Course Object
  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      code: json['code'] ?? '', 
      name: json['name'] ?? '',
    );
  }

  // Method to convert Course Object into JSON Map
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
    };
  }
}