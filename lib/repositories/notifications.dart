import 'dart:convert';
import 'package:studently/models/notifications.dart';
import '../services/api.dart';
import '../logger.dart';

class NotificationRepository {
  // Utilizing your existing ApiService ensures auth tokens are automatically attached
  final ApiService _apiService = ApiService();

  /// 1. Fetch historical notifications from FastAPI.
  /// Pagination (skip/limit) ensures we don't crash the app if a user has thousands of alerts.
  Future<List<AppNotification>> fetchNotifications({
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final response = await _apiService.get(
        '/notifications?skip=$skip&limit=$limit',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // Convert the raw JSON list from Python into our custom Dart objects
        return data.map((json) => AppNotification.fromJson(json)).toList();
      } else {
        logger.e('Failed to fetch notifications: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      logger.e('Error fetching notifications: $e');
      return [];
    }
  }

  /// 2. Tell the backend a notification was clicked/read.
  /// This keeps MongoDB updated, so if they log in on another device, the badge is cleared.
  Future<bool> markAsRead(String notificationId) async {
    try {
      final response = await _apiService.put(
        '/notifications/$notificationId/read',
        body: {},
      );
      return response.statusCode == 200;
    } catch (e) {
      logger.e('Error marking notification as read: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await _apiService.put(
        '/notifications/read-all',
        body: {},
      );
      return response.statusCode == 200;
    } catch (e) {
      logger.e('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// 3. Give FastAPI the phone's unique Firebase token.
  /// We will trigger this inside your AuthProvider right after a successful login.
  Future<bool> registerFcmToken(String token) async {
    try {
      final response = await _apiService.post(
        '/users/fcm-token',
        body: {'token': token},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      logger.e('Error registering FCM token: $e');
      return false;
    }
  }

  /// 4. Remove the token from FastAPI.
  /// Triggered on logout to ensure the user's phone stops receiving push notifications.
  Future<bool> unregisterFcmToken(String token) async {
    try {
      final response = await _apiService.delete('/users/fcm-token/$token');
      return response.statusCode == 200;
    } catch (e) {
      logger.e('Error removing FCM token: $e');
      return false;
    }
  }
}
