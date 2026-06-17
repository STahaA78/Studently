import 'dart:async';
import 'dart:convert';
import 'package:studently/logger.dart';
import 'package:studently/models/teachers.dart';
import 'package:studently/services/analytics_service.dart';
import 'package:studently/services/api.dart';
import 'package:studently/services/storage.dart';
import 'package:studently/storage/teachers.dart';

class TeacherRepository {
  final ApiService _apiService = ApiService();
  TeacherStorage get _storage => StorageService().teacherStorage;

  Future<List<Teacher>> fetchTeachers({bool forceRefresh = false}) async {
    logger.i(
      "[$runtimeType] Fetch Teachers Initiated (forceRefresh: $forceRefresh)",
    );
    try {
      if (!forceRefresh && _storage.hasCachedTeachers()) {
        final cached = _storage.getCachedTeachers();
        cached.sort((a, b) => a.name.compareTo(b.name));
        _refreshTeachersInBackground();
        return cached;
      }

      final headers = <String, String>{};
      final cachedEtag = _storage.getTeachersEtag();
      if (cachedEtag != null && cachedEtag.isNotEmpty) {
        headers['If-None-Match'] = cachedEtag;
      }

      final response = await _apiService.get(
        '/teachers/',
        headers: headers,
        allowNotModified: true,
      );

      if (response.statusCode == 304 && _storage.hasCachedTeachers()) {
        logger.i("[$runtimeType] Teachers unchanged (304)");
        final cached = _storage.getCachedTeachers();
        cached.sort((a, b) => a.name.compareTo(b.name));
        return cached;
      } else if (response.statusCode == 304) {
        logger.w(
          "[$runtimeType] Received 304 for teachers but no cache was available; refetching without ETag",
        );
        final fallbackResponse = await _apiService.get('/teachers/');
        final List<dynamic> fallbackJson = jsonDecode(fallbackResponse.body);
        final fallbackTeachers = fallbackJson
            .map((item) => Teacher.fromJson((item as Map).cast<String, dynamic>()))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        await _storage.saveTeachers(fallbackTeachers);
        final fallbackEtag = fallbackResponse.headers['etag'];
        if (fallbackEtag != null && fallbackEtag.isNotEmpty) {
          await _storage.saveTeachersEtag(fallbackEtag);
        }
        return fallbackTeachers;
      }

      final List<dynamic> jsonData = jsonDecode(response.body);
      final teachers = jsonData
          .map((item) => Teacher.fromJson((item as Map).cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      await _storage.saveTeachers(teachers);
      final etag = response.headers['etag'];
      if (etag != null && etag.isNotEmpty) {
        await _storage.saveTeachersEtag(etag);
      }
      return teachers;
    } catch (e) {
      logger.e("[$runtimeType] Fetch Teachers Failed: $e");
      if (_storage.hasCachedTeachers()) {
        return _storage.getCachedTeachers();
      }
      rethrow;
    }
  }

  Future<void> _refreshTeachersInBackground() async {
    try {
      await fetchTeachers(forceRefresh: true);
    } catch (e) {
      logger.w("[$runtimeType] Background teacher refresh failed: $e");
    }
  }

  Future<TeacherDetail> fetchTeacherDetail(
    String teacherId, {
    bool forceRefresh = false,
  }) async {
    logger.i(
      "[$runtimeType] Fetch Teacher Detail Initiated for $teacherId (forceRefresh: $forceRefresh)",
    );
    try {
      if (!forceRefresh) {
        final cachedReviews = _storage.getCachedReviewsForTeacher(teacherId);
        final cachedTeachers = _storage.getCachedTeachers();
        final cachedTeacher = cachedTeachers.where((t) => t.id == teacherId).toList();
        if (cachedTeacher.isNotEmpty && cachedReviews.isNotEmpty) {
          _refreshTeacherDetailInBackground(teacherId);
          return TeacherDetail(teacher: cachedTeacher.first, reviews: cachedReviews);
        }
      }

      final headers = <String, String>{};
      final cachedEtag = _storage.getTeacherDetailEtag(teacherId);
      if (cachedEtag != null && cachedEtag.isNotEmpty) {
        headers['If-None-Match'] = cachedEtag;
      }

      final response = await _apiService.get(
        '/teachers/$teacherId',
        headers: headers,
        allowNotModified: true,
      );

      if (response.statusCode == 304) {
        final cachedTeachers = _storage.getCachedTeachers();
        final cachedTeacher = cachedTeachers.where((t) => t.id == teacherId).toList();
        final cachedReviews = _storage.getCachedReviewsForTeacher(teacherId);
        if (cachedTeacher.isNotEmpty) {
          logger.i("[$runtimeType] Teacher detail $teacherId unchanged (304)");
          return TeacherDetail(
            teacher: cachedTeacher.first,
            reviews: cachedReviews,
          );
        }
        logger.w(
          "[$runtimeType] Received 304 for teacher $teacherId but no cache was available; refetching without ETag",
        );
        final fallbackResponse = await _apiService.get('/teachers/$teacherId');
        final fallbackData = jsonDecode(fallbackResponse.body) as Map<String, dynamic>;
        final fallbackDetail = TeacherDetail.fromJson(fallbackData);
        await _storage.saveReviewsForTeacher(teacherId, fallbackDetail.reviews);
        final fallbackEtag = fallbackResponse.headers['etag'];
        if (fallbackEtag != null && fallbackEtag.isNotEmpty) {
          await _storage.saveTeacherDetailEtag(teacherId, fallbackEtag);
        }
        final teachers = _storage.getCachedTeachers();
        final index = teachers.indexWhere((t) => t.id == teacherId);
        if (index != -1) {
          teachers[index] = fallbackDetail.teacher;
          await _storage.saveTeachers(teachers);
        }
        return fallbackDetail;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = TeacherDetail.fromJson(data);
      await _storage.saveReviewsForTeacher(teacherId, detail.reviews);
      final etag = response.headers['etag'];
      if (etag != null && etag.isNotEmpty) {
        await _storage.saveTeacherDetailEtag(teacherId, etag);
      }

      final teachers = _storage.getCachedTeachers();
      final index = teachers.indexWhere((t) => t.id == teacherId);
      if (index != -1) {
        teachers[index] = detail.teacher;
        await _storage.saveTeachers(teachers);
      }
      return detail;
    } catch (e) {
      logger.e("[$runtimeType] Fetch Teacher Detail Failed: $e");
      final cachedTeachers = _storage.getCachedTeachers();
      final cachedTeacher = cachedTeachers.where((t) => t.id == teacherId).toList();
      final cachedReviews = _storage.getCachedReviewsForTeacher(teacherId);
      if (cachedTeacher.isNotEmpty) {
        return TeacherDetail(
          teacher: cachedTeacher.first,
          reviews: cachedReviews,
        );
      }
      rethrow;
    }
  }

  Future<void> _refreshTeacherDetailInBackground(String teacherId) async {
    try {
      await fetchTeacherDetail(teacherId, forceRefresh: true);
    } catch (e) {
      logger.w(
        "[$runtimeType] Background teacher detail refresh failed for $teacherId: $e",
      );
    }
  }

  Future<Teacher> createTeacher(TeacherCreateRequest request) async {
    logger.i("[$runtimeType] Create Teacher Initiated");
    final response = await _apiService.post(
      '/teachers/',
      body: request.toJson(),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final teacher = Teacher.fromJson(data);

    final teachers = _storage.getCachedTeachers();
    teachers.removeWhere((t) => t.id == teacher.id);
    teachers.add(teacher);
    teachers.sort((a, b) => a.name.compareTo(b.name));
    await _storage.saveTeachers(teachers);
    unawaited(
      AnalyticsService.logEvent(
        AnalyticsEvents.teacherAdd,
        parameters: {
          'title': request.title,
          'department_code': request.department.code,
          'campus_code': request.campus.code,
          'has_email': request.email?.isNotEmpty ?? false,
          'has_linkedin': request.linkedinProfile?.isNotEmpty ?? false,
        },
      ),
    );

    return teacher;
  }

  Future<TeacherReview> addReview(
    String teacherId,
    TeacherReviewCreateRequest request,
  ) async {
    logger.i("[$runtimeType] Add Review Initiated for teacher $teacherId");
    final response = await _apiService.post(
      '/teachers/$teacherId/reviews',
      body: request.toJson(),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final review = TeacherReview.fromJson(data);

    final cachedReviews = _storage.getCachedReviewsForTeacher(teacherId);
    cachedReviews.insert(0, review);
    await _storage.saveReviewsForTeacher(teacherId, cachedReviews);
    unawaited(
      AnalyticsService.logEvent(
        AnalyticsEvents.teacherReviewAdd,
        parameters: {
          'teacher_id': teacherId,
          'rating': request.rating,
          'anonymous': request.anonymous,
          'content_length': request.content.length,
        },
      ),
    );

    return review;
  }

  Future<Map<String, dynamic>> deleteReview(
    String teacherId,
    String reviewId,
  ) async {
    logger.i(
      "[$runtimeType] Delete Review Initiated for teacher $teacherId review $reviewId",
    );
    final response = await _apiService.delete('/teachers/$teacherId/reviews/$reviewId');
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final cachedReviews = _storage.getCachedReviewsForTeacher(teacherId)
      ..removeWhere((review) => review.id == reviewId);
    await _storage.saveReviewsForTeacher(teacherId, cachedReviews);
    unawaited(
      AnalyticsService.logEvent(
        AnalyticsEvents.teacherReviewDelete,
        parameters: {
          'teacher_id': teacherId,
          'review_id_present': reviewId.isNotEmpty,
        },
      ),
    );

    final teachers = _storage.getCachedTeachers();
    final teacherIndex = teachers.indexWhere((t) => t.id == teacherId);
    if (teacherIndex != -1) {
      final rating = (data['rating'] as num? ?? 0).toDouble();
      final reviewCount = (data['reviewCount'] as num? ?? 0).toInt();
      teachers[teacherIndex] = teachers[teacherIndex].copyWith(
        rating: rating,
        reviewCount: reviewCount,
      );
      await _storage.saveTeachers(teachers);
    }

    return data;
  }
}
