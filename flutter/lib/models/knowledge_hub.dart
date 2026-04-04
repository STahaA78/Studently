import 'package:hive_flutter/hive_flutter.dart';

part 'knowledge_hub.g.dart';

@HiveType(typeId: 0)
class Course {
  @HiveField(0)
  final String code;
  
  @HiveField(1)
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

class ResourceItemRequest {
  final Course course;
  final String type;
  final int year;
  final String semester;
  final String? instructorName;
  final int? quizNumber;
  final bool? isSolved;

  ResourceItemRequest({
    required this.course,
    required this.type,
    required this.year,
    required this.semester,
    this.instructorName,
    this.quizNumber,
    this.isSolved,
  });

  Map<String, dynamic> toJson() {
    return {
      'course': course.toJson(),
      'type': type,
      'year': year,
      'semester': semester,
      'instructorName': instructorName,
      'quizNumber': quizNumber,
      'isSolved': isSolved,
    };
  }
}

@HiveType(typeId: 1)
class ResourceItem {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int year;

  @HiveField(2)
  final String semester;

  @HiveField(3)
  final String? instructorName;

  @HiveField(4)
  final int? quizNumber;

  @HiveField(5)
  final bool? isSolved;

  @HiveField(6)
  final String filePath;

  @HiveField(7)
  final DateTime uploadedAt;

  @HiveField(8)
  final String? localFilePath; // Local storage path for downloaded files

  @HiveField(9)
  final String? type; // Resource type: 'final', 'quiz', 'midterm', 'book'

  ResourceItem({
    required this.id,
    required this.year,
    required this.semester,
    this.instructorName,
    this.quizNumber,
    this.isSolved,
    required this.filePath,
    required this.uploadedAt,
    this.localFilePath,
    this.type,
  });

  factory ResourceItem.fromJson(Map<String, dynamic> json) {
    return ResourceItem(
      id: json['id'],
      year: json['year'],
      semester: json['semester'],
      instructorName: json['instructorName'],
      quizNumber: json['quizNumber'],
      filePath: json['filePath'],
      isSolved: json['isSolved'],
      uploadedAt: DateTime.parse(json['uploadedAt']),
      type: json['type'] ?? '',
    );
  }

  // Create a copy with updated fields
  ResourceItem copyWith({String? localFilePath, String? type}) {
    return ResourceItem(
      id: id,
      year: year,
      semester: semester,
      instructorName: instructorName,
      quizNumber: quizNumber,
      isSolved: isSolved,
      filePath: filePath,
      uploadedAt: uploadedAt,
      localFilePath: localFilePath ?? this.localFilePath,
      type: type ?? this.type,
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