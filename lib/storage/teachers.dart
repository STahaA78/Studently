import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:studently/logger.dart';
import 'package:studently/models/teachers.dart';

class TeacherStorage {
  static const String _teachersBoxName = 'teachers_cache';
  static const String _reviewsBoxName = 'teacher_reviews_cache';
  static const String _metadataBoxName = 'teacher_metadata_cache';

  late Box<String> _teachersBox;
  late Box<String> _reviewsBox;
  late Box<String> _metadataBox;
  bool _isInitialized = false;

  static final TeacherStorage _instance = TeacherStorage._internal();

  TeacherStorage._internal();

  factory TeacherStorage() => _instance;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _teachersBox = await Hive.openBox<String>(_teachersBoxName);
      _reviewsBox = await Hive.openBox<String>(_reviewsBoxName);
      _metadataBox = await Hive.openBox<String>(_metadataBoxName);
      _isInitialized = true;
      logger.i('[TeacherStorage] Initialized successfully');
    } catch (e) {
      logger.e('[TeacherStorage] Error initializing storage: $e');
      rethrow;
    }
  }

  bool _ensureInitialized({bool throwOnFailure = false}) {
    if (_isInitialized) return true;

    const message =
        '[TeacherStorage] Accessed before initialization. Call init() first.';
    if (throwOnFailure) {
      throw StateError(message);
    }
    logger.w(message);
    return false;
  }

  Future<void> saveTeachers(List<Teacher> teachers) async {
    _ensureInitialized(throwOnFailure: true);
    try {
      await _teachersBox.put(
        'teachers',
        jsonEncode(teachers.map((t) => t.toJson()).toList()),
      );
      logger.i('[TeacherStorage] Saved ${teachers.length} teachers');
    } catch (e) {
      logger.e('[TeacherStorage] Error saving teachers: $e');
      rethrow;
    }
  }

  Future<void> saveTeachersEtag(String etag) async {
    _ensureInitialized(throwOnFailure: true);
    await _metadataBox.put('teachers_etag', etag);
  }

  String? getTeachersEtag() {
    if (!_ensureInitialized()) return null;
    return _metadataBox.get('teachers_etag');
  }

  List<Teacher> getCachedTeachers() {
    if (!_ensureInitialized()) return [];

    try {
      final raw = _teachersBox.get('teachers');
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Teacher.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      logger.e('[TeacherStorage] Error reading teachers cache: $e');
      return [];
    }
  }

  bool hasCachedTeachers() {
    if (!_ensureInitialized()) return false;
    return _teachersBox.containsKey('teachers');
  }

  Future<void> saveReviewsForTeacher(
    String teacherId,
    List<TeacherReview> reviews,
  ) async {
    _ensureInitialized(throwOnFailure: true);
    try {
      await _reviewsBox.put(
        teacherId,
        jsonEncode(reviews.map((r) => r.toJson()).toList()),
      );
      logger.i(
        '[TeacherStorage] Saved ${reviews.length} cached reviews for teacher $teacherId',
      );
    } catch (e) {
      logger.e('[TeacherStorage] Error saving reviews: $e');
      rethrow;
    }
  }

  Future<void> saveTeacherDetailEtag(String teacherId, String etag) async {
    _ensureInitialized(throwOnFailure: true);
    await _metadataBox.put('teacher_detail_etag:$teacherId', etag);
  }

  String? getTeacherDetailEtag(String teacherId) {
    if (!_ensureInitialized()) return null;
    return _metadataBox.get('teacher_detail_etag:$teacherId');
  }

  List<TeacherReview> getCachedReviewsForTeacher(String teacherId) {
    if (!_ensureInitialized()) return [];

    try {
      final raw = _reviewsBox.get(teacherId);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => TeacherReview.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      logger.e(
        '[TeacherStorage] Error reading cached reviews for teacher $teacherId: $e',
      );
      return [];
    }
  }

  Future<void> clearStorage() async {
    _ensureInitialized(throwOnFailure: true);
    try {
      await _teachersBox.clear();
      await _reviewsBox.clear();
      await _metadataBox.clear();
      logger.i('[TeacherStorage] Cleared teacher cache');
    } catch (e) {
      logger.e('[TeacherStorage] Error clearing teacher cache: $e');
      rethrow;
    }
  }
}
