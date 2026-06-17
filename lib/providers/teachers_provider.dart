import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/logger.dart';
import 'package:studently/models/backend_config.dart';
import 'package:studently/models/teachers.dart';
import 'package:studently/providers/cache_freshness_provider.dart';
import 'package:studently/repositories/teachers.dart';
import 'package:studently/services/storage.dart';

final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  return TeacherRepository();
});

class TeachersState {
  final List<Teacher> teachers;
  final bool isSubmitting;
  final bool hasLoadedTeachers;

  const TeachersState({
    this.teachers = const [],
    this.isSubmitting = false,
    this.hasLoadedTeachers = false,
  });

  TeachersState copyWith({
    List<Teacher>? teachers,
    bool? isSubmitting,
    bool? hasLoadedTeachers,
  }) {
    return TeachersState(
      teachers: teachers ?? this.teachers,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      hasLoadedTeachers: hasLoadedTeachers ?? this.hasLoadedTeachers,
    );
  }
}

class TeachersNotifier extends AsyncNotifier<TeachersState> {
  final _storage = StorageService().teacherStorage;
  Timer? _refreshTimer;

  @override
  Future<TeachersState> build() async {
    final cachedTeachers = _storage.getCachedTeachers();

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      silentRefresh();
    });
    ref.onDispose(() => _refreshTimer?.cancel());

    if (cachedTeachers.isEmpty) {
      await _fetchTeachers(showError: false);
      if (state.hasError) {
        throw state.error!;
      }
      return state.value ?? const TeachersState(hasLoadedTeachers: true);
    }

    unawaited(_fetchTeachers(showError: false));

    return TeachersState(
      teachers: cachedTeachers,
      hasLoadedTeachers: true,
    );
  }

  Future<void> _fetchTeachers({required bool showError}) async {
    final cache = ref.read(cacheCoordinatorProvider);
    if (!cache.tryBeginRefresh(CacheDomain.teachers)) {
      return;
    }

    try {
      final repo = ref.read(teacherRepositoryProvider);
      final teachers = await repo.fetchTeachers(forceRefresh: true);
      state = AsyncValue.data(
        TeachersState(
          teachers: teachers,
          hasLoadedTeachers: true,
        ),
      );
      cache.endRefresh(CacheDomain.teachers, success: true);
    } catch (e, stack) {
      logger.e('[TeachersNotifier] fetchTeachers failed: $e', error: e, stackTrace: stack);
      cache.endRefresh(CacheDomain.teachers, success: false);
      if (showError || (state.value?.teachers.isEmpty ?? true)) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> refresh() async {
    ref.read(cacheCoordinatorProvider).invalidate(CacheDomain.teachers);
    state = AsyncValue.data(
      (state.value ?? const TeachersState()).copyWith(isSubmitting: false),
    );
    await _fetchTeachers(showError: true);
  }

  Future<void> silentRefresh() async {
    await _fetchTeachers(showError: false);
  }

  Future<Teacher?> createTeacher(TeacherCreateRequest request) async {
    final current = state.value ?? const TeachersState();
    state = AsyncValue.data(current.copyWith(isSubmitting: true));
    try {
      final repo = ref.read(teacherRepositoryProvider);
      final created = await repo.createTeacher(request);
      final nextState = current.copyWith(
        isSubmitting: false,
        hasLoadedTeachers: true,
      );
      state = AsyncValue.data(nextState);
      ref.read(cacheCoordinatorProvider).invalidate(CacheDomain.teachers);
      return created;
    } catch (e, stack) {
      state = AsyncValue.data(current.copyWith(isSubmitting: false));
      logger.e('[TeachersNotifier] createTeacher failed: $e', error: e, stackTrace: stack);
      rethrow;
    }
  }
}

final teachersProvider =
    AsyncNotifierProvider.autoDispose<TeachersNotifier, TeachersState>(
      () => TeachersNotifier(),
    );

class TeacherDetailState {
  final Teacher teacher;
  final List<TeacherReview> reviews;
  final bool isSubmittingReview;
  final bool hasLoadedReviews;

  const TeacherDetailState({
    required this.teacher,
    this.reviews = const [],
    this.isSubmittingReview = false,
    this.hasLoadedReviews = false,
  });

  TeacherDetailState copyWith({
    Teacher? teacher,
    List<TeacherReview>? reviews,
    bool? isSubmittingReview,
    bool? hasLoadedReviews,
  }) {
    return TeacherDetailState(
      teacher: teacher ?? this.teacher,
      reviews: reviews ?? this.reviews,
      isSubmittingReview: isSubmittingReview ?? this.isSubmittingReview,
      hasLoadedReviews: hasLoadedReviews ?? this.hasLoadedReviews,
    );
  }
}

class TeacherDetailNotifier extends AsyncNotifier<TeacherDetailState> {
  final String teacherId;
  TeacherDetailNotifier(this.teacherId);

  final _storage = StorageService().teacherStorage;
  Timer? _refreshTimer;

  @override
  Future<TeacherDetailState> build() async {
    final cachedTeachers = _storage.getCachedTeachers();
    final cachedTeacher = cachedTeachers.where((t) => t.id == teacherId).toList();
    final cachedReviews = _storage.getCachedReviewsForTeacher(teacherId);

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      silentRefresh();
    });
    ref.onDispose(() => _refreshTimer?.cancel());

    if (cachedTeacher.isNotEmpty && cachedReviews.isNotEmpty) {
      unawaited(_fetchDetail(showError: false));
      return TeacherDetailState(
        teacher: cachedTeacher.first,
        reviews: cachedReviews,
        hasLoadedReviews: true,
      );
    }

    await _fetchDetail(showError: false);
    if (state.hasError) {
      throw state.error!;
    }
    return state.value ??
        TeacherDetailState(
          teacher: cachedTeacher.isNotEmpty
              ? cachedTeacher.first
              : Teacher(
                  id: teacherId,
                  title: '',
                  name: 'Teacher',
                  department: Department(name: '', code: ''),
                  campus: Campus(name: '', code: ''),
                  rating: 0,
                  reviewCount: 0,
                  approved: true,
                ),
        );
  }

  Future<void> _fetchDetail({required bool showError}) async {
    final cache = ref.read(cacheCoordinatorProvider);
    if (!cache.tryBeginRefresh(CacheDomain.teacherReviews, scopeId: teacherId)) {
      return;
    }

    try {
      final repo = ref.read(teacherRepositoryProvider);
      final detail = await repo.fetchTeacherDetail(teacherId, forceRefresh: true);
      state = AsyncValue.data(
        TeacherDetailState(
          teacher: detail.teacher,
          reviews: detail.reviews,
          hasLoadedReviews: true,
        ),
      );
      cache.endRefresh(CacheDomain.teacherReviews, success: true, scopeId: teacherId);
    } catch (e, stack) {
      logger.e('[TeacherDetailNotifier] fetchDetail failed: $e', error: e, stackTrace: stack);
      cache.endRefresh(CacheDomain.teacherReviews, success: false, scopeId: teacherId);
      if (showError || (state.value?.reviews.isEmpty ?? true)) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> refresh() async {
    ref.read(cacheCoordinatorProvider).invalidate(
      CacheDomain.teacherReviews,
      scopeId: teacherId,
    );
    await _fetchDetail(showError: true);
  }

  Future<void> silentRefresh() async {
    await _fetchDetail(showError: false);
  }

  Future<void> addReview(TeacherReviewCreateRequest request) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncValue.data(current.copyWith(isSubmittingReview: true));
    try {
      final repo = ref.read(teacherRepositoryProvider);
      final review = await repo.addReview(teacherId, request);
      final updatedReviews = [review, ...current.reviews];
      final approvedReviews =
          updatedReviews.where((review) => review.approved).toList();
      final updatedTeacher = current.teacher.copyWith(
        reviewCount: approvedReviews.length,
        rating: approvedReviews.isEmpty
            ? 0
            : approvedReviews.map((r) => r.rating).reduce((a, b) => a + b) /
                approvedReviews.length,
      );
      final nextState = current.copyWith(
        teacher: updatedTeacher,
        reviews: updatedReviews,
        isSubmittingReview: false,
        hasLoadedReviews: true,
      );
      state = AsyncValue.data(nextState);
      ref.read(cacheCoordinatorProvider).invalidate(
        CacheDomain.teacherReviews,
        scopeId: teacherId,
      );
    } catch (e, stack) {
      logger.e('[TeacherDetailNotifier] addReview failed: $e', error: e, stackTrace: stack);
      state = AsyncValue.data(current.copyWith(isSubmittingReview: false));
      rethrow;
    }
  }

  Future<void> deleteReview(String reviewId) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncValue.data(current.copyWith(isSubmittingReview: true));
    try {
      final repo = ref.read(teacherRepositoryProvider);
      await repo.deleteReview(teacherId, reviewId);
      final updatedReviews =
          current.reviews.where((review) => review.id != reviewId).toList();
      final approvedReviews =
          updatedReviews.where((review) => review.approved).toList();
      final updatedTeacher = current.teacher.copyWith(
        reviewCount: approvedReviews.length,
        rating: approvedReviews.isEmpty
            ? 0
            : approvedReviews.map((r) => r.rating).reduce((a, b) => a + b) /
                approvedReviews.length,
      );
      final nextState = current.copyWith(
        teacher: updatedTeacher,
        reviews: updatedReviews,
        isSubmittingReview: false,
        hasLoadedReviews: true,
      );
      state = AsyncValue.data(nextState);
      ref.read(cacheCoordinatorProvider).invalidate(
        CacheDomain.teacherReviews,
        scopeId: teacherId,
      );
    } catch (e, stack) {
      logger.e('[TeacherDetailNotifier] deleteReview failed: $e', error: e, stackTrace: stack);
      state = AsyncValue.data(current.copyWith(isSubmittingReview: false));
      rethrow;
    }
  }
}

final teacherDetailProvider = AsyncNotifierProvider.autoDispose.family<
  TeacherDetailNotifier,
  TeacherDetailState,
  String
>((teacherId) {
  return TeacherDetailNotifier(teacherId);
});
