import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/logger.dart';
import 'package:studently/models/notifications.dart';
import 'package:studently/repositories/notifications.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/storage/notifications.dart';

class NotificationState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final bool initialized;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.initialized = false,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    bool? initialized,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      initialized: initialized ?? this.initialized,
    );
  }
}

class NotificationController extends Notifier<NotificationState> {
  final NotificationRepository _repository = NotificationRepository();
  final NotificationStorage _storage = NotificationStorage();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<String>? _tokenRefreshSub;

  String? _registeredToken;
  String? _initializedUid;

  @override
  NotificationState build() {
    ref.onDispose(() async {
      await _messageSub?.cancel();
      await _tokenRefreshSub?.cancel();
    });

    return const NotificationState();
  }

  Future<void> initializeForCurrentUser() async {
    final uid = authService.value.currentUser?.uid;
    if (uid == null) {
      await clearForLogout();
      return;
    }

    if (_initializedUid == uid && state.initialized) {
      return;
    }

    _initializedUid = uid;
    state = state.copyWith(
      isLoading: true,
      notifications: _storage.getCachedNotifications(),
    );

    await _configureMessaging(uid);
    await refreshFromServer();

    state = state.copyWith(isLoading: false, initialized: true);
  }

  Future<void> refreshFromServer() async {
    try {
      final fresh = await _repository.fetchNotifications(skip: 0, limit: 100);
      state = state.copyWith(notifications: fresh);
      await _storage.saveNotifications(fresh);
    } catch (e) {
      logger.e('[NotificationController] refresh failed: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    final index = state.notifications.indexWhere((n) => n.id == id);
    if (index == -1) return;

    final current = state.notifications[index];
    if (current.isRead) return;

    final updated = List<AppNotification>.from(state.notifications);
    updated[index].isRead = true;
    state = state.copyWith(notifications: updated);

    await _storage.markAsReadLocally(id);
    await _repository.markAsRead(id);
  }

  Future<void> clearForLogout() async {
    if (_registeredToken != null) {
      await _repository.unregisterFcmToken(_registeredToken!);
      _registeredToken = null;
    }

    _initializedUid = null;
    state = const NotificationState(notifications: []);
    await _storage.clearStorage();
  }

  Future<void> markAllAsRead() async {
    final hasUnread = state.notifications.any((n) => !n.isRead);
    if (!hasUnread) return;

    final updated = List<AppNotification>.from(state.notifications);
    for (final notification in updated) {
      notification.isRead = true;
    }
    state = state.copyWith(notifications: updated);
    await _storage.saveNotifications(updated);

    final success = await _repository.markAllAsRead();
    if (!success) {
      // Soft recovery: refresh from backend if bulk update fails.
      await refreshFromServer();
    }
  }

  Future<void> _configureMessaging(String uid) async {
    await _messageSub?.cancel();
    await _tokenRefreshSub?.cancel();

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    logger.i(
      '[NotificationController] Notification permission: ${settings.authorizationStatus}',
    );

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      _registeredToken = token;
      await _repository.registerFcmToken(token);
    }

    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      if (token.isEmpty) return;
      _registeredToken = token;
      await _repository.registerFcmToken(token);
    });

    _messageSub = FirebaseMessaging.onMessage.listen((RemoteMessage _) async {
      if (authService.value.currentUser?.uid != uid) return;
      await refreshFromServer();
    });
  }
}

final notificationProvider =
    NotifierProvider<NotificationController, NotificationState>(
      NotificationController.new,
    );
