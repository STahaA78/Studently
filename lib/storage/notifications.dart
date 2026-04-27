import 'package:hive/hive.dart';
import 'package:studently/models/notifications.dart';
import '../logger.dart'; 

class NotificationStorage {
  // This matches the box name we opened in hive_init.dart
  static const String _boxName = 'notificationsBox';

  // Helper to easily access the box
  Box<AppNotification> get _box => Hive.box<AppNotification>(_boxName);

  /// 1. Save a batch of notifications (usually when fetching from the API)
  Future<void> saveNotifications(List<AppNotification> notifications) async {
    try {
      // We convert the list into a Map where the Key is the ID.
      // Using putAll updates existing ones and adds new ones seamlessly.
      final Map<String, AppNotification> notificationMap = {
        for (var n in notifications) n.id: n
      };
      await _box.putAll(notificationMap);
      logger.i('Saved ${notifications.length} notifications to local cache.');
    } catch (e) {
      logger.e('Error saving notifications to Hive: $e');
    }
  }

  /// 2. Save a single notification (used when a live FCM message arrives)
  Future<void> saveSingleNotification(AppNotification notification) async {
    try {
      await _box.put(notification.id, notification);
    } catch (e) {
      logger.e('Error saving live notification to Hive: $e');
    }
  }

  /// 3. Retrieve all cached notifications, sorted newest to oldest
  List<AppNotification> getCachedNotifications() {
    try {
      final notifications = _box.values.toList();
      // Sort them so the newest ones appear at the top of the UI
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    } catch (e) {
      logger.e('Error reading notifications from Hive: $e');
      return [];
    }
  }

  /// 4. Mark a notification as read locally so the UI updates instantly
  Future<void> markAsReadLocally(String id) async {
    try {
      final notification = _box.get(id);
      if (notification != null) {
        notification.isRead = true;
        await _box.put(id, notification); // Re-save it with isRead = true
      }
    } catch (e) {
      logger.e('Error marking notification read in Hive: $e');
    }
  }

  /// 5. Wipe the local storage (Call this when the user logs out)
  Future<void> clearStorage() async {
    try {
      await _box.clear();
      logger.i('Notification cache cleared.');
    } catch (e) {
      logger.e('Error clearing notification cache: $e');
    }
  }
}