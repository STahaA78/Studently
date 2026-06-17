import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:studently/models/user.dart';

class AnalyticsEvents {
  static const String screenView = 'screen_view';
  static const String discoverCardSwipe = 'discover_card_swipe';
  static const String discoverFilterChanged = 'discover_filter_changed';
  static const String courseOpen = 'course_open';
  static const String courseAdd = 'course_add';
  static const String resourceOpen = 'resource_open';
  static const String resourceAdd = 'resource_add';
  static const String teacherOpen = 'teacher_open';
  static const String teacherAdd = 'teacher_add';
  static const String teacherReviewAdd = 'teacher_review_add';
  static const String teacherReviewDelete = 'teacher_review_delete';
  static const String apiRequest = 'api_request';
  static const String apiRequestFailed = 'api_request_failed';
}

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static FirebaseAnalytics get instance => _analytics;

  static final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: _analytics,
  );

  static Future<void> setUserContext({User? user}) async {
    try {
      if (user == null) {
        await _analytics.setUserId(id: null);
        await _analytics.setUserProperty(name: 'campus_code', value: null);
        await _analytics.setUserProperty(name: 'department_code', value: null);
        await _analytics.setUserProperty(name: 'batch_year', value: null);
        return;
      }

      await _analytics.setUserId(id: user.id);
      await _analytics.setUserProperty(
        name: 'campus_code',
        value: user.campus?.code,
      );
      await _analytics.setUserProperty(
        name: 'department_code',
        value: user.department?.code,
      );
      await _analytics.setUserProperty(name: 'batch_year', value: user.batch);
    } catch (_) {
      // Analytics should never block the app.
    }
  }

  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (_) {}
  }

  static Future<void> logEvent(
    String name, {
    Map<String, Object?>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: _sanitizeParameters(parameters),
      );
    } catch (_) {}
  }

  static Future<void> logApiRequest({
    required String method,
    required String endpoint,
    required int statusCode,
    required int durationMs,
    required bool success,
    String? source,
    String? errorType,
    String? cacheResult,
  }) async {
    await logEvent(
      success ? AnalyticsEvents.apiRequest : AnalyticsEvents.apiRequestFailed,
      parameters: {
        'method': method,
        'endpoint': endpoint,
        'status_code': statusCode,
        'duration_ms': durationMs,
        'source': source ?? 'api_service',
        'success': success ? 1 : 0,
        'error_type': ?errorType,
        'cache_result': ?cacheResult,
      },
    );
  }

  static Future<void> logApiFailure({
    required String method,
    required String endpoint,
    required int durationMs,
    required String errorType,
    String? source,
  }) async {
    await logEvent(
      AnalyticsEvents.apiRequestFailed,
      parameters: {
        'method': method,
        'endpoint': endpoint,
        'duration_ms': durationMs,
        'source': source ?? 'api_service',
        'error_type': errorType,
      },
    );
  }

  static Map<String, Object> _sanitizeParameters(
    Map<String, Object?>? parameters,
  ) {
    final cleaned = <String, Object>{};
    if (parameters == null) return cleaned;

    for (final entry in parameters.entries) {
      final value = entry.value;
      if (value == null) continue;

      if (value is bool) {
        cleaned[entry.key] = value ? 1 : 0;
      } else if (value is num || value is String) {
        cleaned[entry.key] = value;
      } else {
        cleaned[entry.key] = value.toString();
      }
    }

    return cleaned;
  }
}
