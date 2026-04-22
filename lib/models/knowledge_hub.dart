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
  final String type; // 'Mid' or 'Final'
  final int year;
  final String semester;
  final bool? isSolved;
  final int? midNumber; // Optional, 1 or 2

  ResourceItemRequest({
    required this.course,
    required this.type,
    required this.year,
    required this.semester,
    this.isSolved,
    this.midNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'course': course.toJson(),
      'type': type,
      'year': year,
      'semester': semester,
      'is_solved': isSolved,
      'mid_number': midNumber,
    };
  }
}

@HiveType(typeId: 1)
class ResourceItem {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final Course course;

  @HiveField(2)
  final String type; // 'Mid' or 'Final'

  @HiveField(3)
  final int year;

  @HiveField(4)
  final String semester;

  @HiveField(5)
  final bool? isSolved;

  @HiveField(6)
  final int? midNumber; // Optional, 1 or 2

  @HiveField(7)
  final String fileUrl;

  @HiveField(8)
  final DateTime uploadedAt;

  @HiveField(9)
  final String uploadedBy;

  @HiveField(10)
  final bool approved;

  @HiveField(11)
  final String? localFilePath; // Local storage path for downloaded files

  ResourceItem({
    required this.id,
    required this.course,
    required this.type,
    required this.year,
    required this.semester,
    this.isSolved,
    this.midNumber,
    required this.fileUrl,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.approved,
    this.localFilePath,
  });

  factory ResourceItem.fromJson(Map<String, dynamic> json) {
    return ResourceItem(
      id: json['id'],
      course: Course.fromJson(json['course']),
      type: json['type'],
      year: json['year'],
      semester: json['semester'],
      isSolved: json['is_solved'],
      midNumber: json['mid_number'],
      fileUrl: (json['file_url'] as String).replaceAll(' ', '%20'),
      uploadedAt: DateTime.parse(json['uploaded_at']),
      uploadedBy: json['uploaded_by'],
      approved: json['approved'] ?? false,
    );
  }

  // Create a copy with updated fields
  ResourceItem copyWith({String? localFilePath}) {
    return ResourceItem(
      id: id,
      course: course,
      type: type,
      year: year,
      semester: semester,
      isSolved: isSolved,
      midNumber: midNumber,
      fileUrl: fileUrl,
      uploadedAt: uploadedAt,
      uploadedBy: uploadedBy,
      approved: approved,
      localFilePath: localFilePath ?? this.localFilePath,
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