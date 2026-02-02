import 'package:studently/models/course.dart';

class ResourceItem {
  final String id;
  final int year;
  final String semester;
  final String? instructorName;
  final int? quizNumber;
  final String filePath;
  final DateTime uploadedAt;

  ResourceItem({
    required this.id,
    required this.year,
    required this.semester,
    this.instructorName,
    this.quizNumber,
    required this.filePath,
    required this.uploadedAt,
  });

  factory ResourceItem.fromJson(Map<String, dynamic> json) {
    return ResourceItem(
      id: json['id'],
      year: json['year'],
      semester: json['semester'],
      instructorName: json['instructorName'],
      quizNumber: json['quizNumber'],
      filePath: json['filePath'],
      uploadedAt: DateTime.parse(json['uploadedAt']),
    );
  }
}

class ResourceGroup {
  final Course course;
  final Map<String, List<ResourceItem>> resources;

  ResourceGroup({required this.course, required this.resources});

  factory ResourceGroup.fromJson(Map<String, dynamic> json) {
    final resMap = json['resources'] as Map<String, dynamic>;
    
    // Map each key in the JSON to a List of ResourceItem
    Map<String, List<ResourceItem>> mappedRes = {};
    resMap.forEach((key, value) {
      mappedRes[key] = (value as List)
          .map((e) => ResourceItem.fromJson(e))
          .toList();
    });

    return ResourceGroup(
      course: Course.fromJson(json['course']),
      resources: mappedRes,
    );
  }
}