import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/logger.dart';
import 'package:studently/models/notifications.dart';
import 'package:studently/providers/feed_provider.dart';
import 'package:studently/repositories/notifications.dart';
import 'package:studently/repositories/chat.dart';
import 'package:studently/screens/chat_page.dart';
import 'package:studently/screens/notifications_page.dart';
import 'package:studently/screens/post_details_page.dart';
import 'package:studently/screens/profile_main.dart';
import 'package:studently/services/app_navigation.dart';
import 'package:studently/services/chat_presence.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/services/storage.dart';

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
  final _storage = StorageService().notificationStorage;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;
  StreamSubscription<String>? _tokenRefreshSub;
  Timer? _fallbackSyncTimer;
  Map<String, dynamic>? _pendingTapPayload;
  bool _isTapRoutingInProgress = false;

  String? _registeredToken;
  String? _initializedUid;
  bool _localNotificationsInitialized = false;
  bool _consumedInitialLocalNotificationLaunch = false;

  @override
  NotificationState build() {
    ref.onDispose(() async {
      await _messageSub?.cancel();
      await _messageOpenedSub?.cancel();
      await _tokenRefreshSub?.cancel();
      _fallbackSyncTimer?.cancel();
      _pendingTapPayload = null;
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
    await processPendingTapIfAny();

    state = state.copyWith(isLoading: false, initialized: true);
  }

  Future<void> refreshFromServer() async {
    try {
      final fresh = await _repository.fetchNotifications(skip: 0, limit: 100);
      final visible = _filterVisibleNotifications(fresh);
      state = state.copyWith(notifications: visible);
      await _storage.saveNotifications(visible);
    } catch (e) {
      logger.e('[NotificationController] refresh failed: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    final index = state.notifications.indexWhere((n) => n.id == id);
    if (index == -1) {
      await _repository.markAsRead(id);
      await _clearSystemNotificationsIfSupported();
      return;
    }

    final current = state.notifications[index];
    if (current.isRead) return;

    final updated = List<AppNotification>.from(state.notifications);
    updated[index].isRead = true;
    state = state.copyWith(notifications: updated);

    await _storage.markAsReadLocally(id);
    await _repository.markAsRead(id);
    await _clearSystemNotificationsIfSupported();
  }

  Future<void> clearForLogout() async {
    if (_registeredToken != null) {
      await _repository.unregisterFcmToken(_registeredToken!);
      _registeredToken = null;
    }

    await _messageSub?.cancel();
    await _messageOpenedSub?.cancel();
    await _tokenRefreshSub?.cancel();
    _fallbackSyncTimer?.cancel();

    _initializedUid = null;
    _pendingTapPayload = null;
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
      await refreshFromServer();
      return;
    }
    await _clearSystemNotificationsIfSupported();
  }

  Future<void> _configureMessaging(String uid) async {
    await _messageSub?.cancel();
    await _messageOpenedSub?.cancel();
    await _tokenRefreshSub?.cancel();
    _fallbackSyncTimer?.cancel();
    await _initializeLocalNotifications();

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

    _messageSub = FirebaseMessaging.onMessage.listen((message) async {
      if (!_isSessionCompatible(uid)) return;
      final messageType = message.data['type']?.toString();
      final entityId = message.data['entity_id']?.toString();
      final isActiveChatMessage =
          messageType == 'NEW_MESSAGE' &&
          entityId == ChatPresence.activeConversationId;

      await _handleForegroundMessage(message);

      // If user is already in this conversation, keep notifications quiet and
      // avoid pulling this message-notification into the list.
      if (isActiveChatMessage && entityId != null) {
        _removeConversationMessageNotifications(entityId);
        try {
          await ChatRepository().markChatAsRead(entityId);
        } catch (_) {}
        return;
      }

      await refreshFromServer();
    });

    _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) async {
      if (!_isSessionCompatible(uid)) return;
      await refreshFromServer();
      await _routeByPayloadOrQueue(message.data);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null && _isSessionCompatible(uid)) {
      await refreshFromServer();
      await _routeByPayloadOrQueue(initialMessage.data);
    }

    _fallbackSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (authService.value.currentUser?.uid != uid) return;
      final serverUnread = await _repository.fetchUnreadCount();
      if (serverUnread == null) return;
      if (serverUnread != state.unreadCount) {
        await refreshFromServer();
      }
    });
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@drawable/ic_launcher_foreground',
      );
      const settings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) async {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            await refreshFromServer();
            await _routeByPayloadOrQueue(data);
          } catch (e) {
            logger.w(
              '[NotificationController] Invalid local notification payload: $e',
            );
          }
        },
      );

      if (!_consumedInitialLocalNotificationLaunch) {
        final launchDetails = await _localNotifications
            .getNotificationAppLaunchDetails();
        final launchResponse = launchDetails?.notificationResponse;
        final launchPayload = launchResponse?.payload;
        if (launchDetails?.didNotificationLaunchApp == true &&
            launchPayload != null &&
            launchPayload.isNotEmpty) {
          try {
            final data = jsonDecode(launchPayload) as Map<String, dynamic>;
            await _routeByPayloadOrQueue(data);
          } catch (e) {
            logger.w('[NotificationController] Invalid launch payload: $e');
          }
        }
        _consumedInitialLocalNotificationLaunch = true;
      }

      const channel = AndroidNotificationChannel(
        'studently_notifications',
        'Studently Notifications',
        description: 'Foreground notifications for Studently updates.',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      _localNotificationsInitialized = true;
    } catch (e) {
      logger.w('[NotificationController] Local notification init skipped: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final messageType = message.data['type']?.toString();
    final entityId = message.data['entity_id']?.toString();

    if (messageType == 'NEW_MESSAGE' &&
        entityId != null &&
        entityId == ChatPresence.activeConversationId) {
      return;
    }

    final title = message.notification?.title ?? 'Studently';
    final body = message.notification?.body ?? 'You have a new update.';

    try {
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'studently_notifications',
            'Studently Notifications',
            channelDescription:
                'Foreground notifications for Studently updates.',
            icon: 'ic_launcher_foreground',
            importance: Importance.high,
            priority: Priority.max,
            color: const Color(0xFF1976D2),
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: title,
              summaryText: 'Studently',
            ),
            ticker: 'Studently update',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      logger.w(
        '[NotificationController] Foreground local notification skipped: $e',
      );
    }
  }

  AppNotification? _findById(String id) {
    for (final n in state.notifications) {
      if (n.id == id) return n;
    }
    return null;
  }

  List<AppNotification> _filterVisibleNotifications(
    List<AppNotification> input,
  ) {
    return input.where((n) => n.type != 'NEW_MESSAGE').toList();
  }

  void _removeConversationMessageNotifications(String conversationId) {
    final next = state.notifications
        .where(
          (n) => !(n.type == 'NEW_MESSAGE' && n.entityId == conversationId),
        )
        .toList();
    state = state.copyWith(notifications: next);
    _storage.saveNotifications(next);
  }

  Future<void> _clearSystemNotificationsIfSupported() async {
    if (kIsWeb || !_localNotificationsInitialized) return;
    try {
      await _localNotifications.cancelAll();
    } catch (_) {}
  }

  Future<void> _routeByPayloadOrQueue(Map<String, dynamic> payload) async {
    _pendingTapPayload = payload;
    await processPendingTapIfAny();
  }

  bool _isSessionCompatible(String uid) {
    final currentUid = authService.value.currentUser?.uid;
    return currentUid == null || currentUid == uid;
  }

  Future<void> processPendingTapIfAny() async {
    final pending = _pendingTapPayload;
    if (pending == null) return;

    // Wait until UI tree has drawn so navigator routes are safe.
    await Future<void>.delayed(Duration.zero);
    final handled = await _routeByPayload(pending);
    if (handled) {
      _pendingTapPayload = null;
    }
  }

  Future<bool> _routeByPayload(Map<String, dynamic> payload) async {
    if (_isTapRoutingInProgress) return false;
    if (authService.value.currentUser == null) return false;

    final type = payload['type']?.toString() ?? '';
    final payloadNotificationId = payload['notification_id']?.toString() ?? '';
    var entityId = payload['entity_id']?.toString() ?? '';
    var actorId = payload['actor_id']?.toString() ?? '';

    AppNotification? appNotification;
    if (payloadNotificationId.isNotEmpty) {
      appNotification = _findById(payloadNotificationId);
      if (appNotification == null) {
        await refreshFromServer();
        appNotification = _findById(payloadNotificationId);
      }
      await markAsRead(payloadNotificationId);
    }

    if (entityId.isEmpty) {
      entityId = appNotification?.entityId ?? '';
    }
    if (actorId.isEmpty) {
      actorId = appNotification?.actorId ?? '';
    }

    final navigator = appNavigatorKey.currentState;
    if (navigator == null || appNavigatorKey.currentContext == null) {
      return false;
    }

    _isTapRoutingInProgress = true;
    try {
      Future<void> openNotificationsFallback() async {
        await navigator.push(
          MaterialPageRoute(builder: (_) => const NotificationsPage()),
        );
      }

      switch (type) {
        case 'NEW_MESSAGE':
          if (entityId.isEmpty) {
            await openNotificationsFallback();
            return true;
          }
          var otherUserName = 'Chat';
          if (actorId.isNotEmpty) {
            try {
              otherUserName = await ChatRepository().getUserName(actorId);
            } catch (_) {}
          }
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => ChatPage(
                conversationId: entityId,
                otherUserId: actorId.isNotEmpty ? actorId : 'UNKNOWN',
                otherUserName: otherUserName,
              ),
            ),
          );
          return true;

        case 'POST_LIKE':
        case 'NEW_COMMENT':
          if (entityId.isEmpty) {
            await openNotificationsFallback();
            return true;
          }
          try {
            final repo = ref.read(postRepositoryProvider);
            final post = await repo.getPostById(entityId);
            await navigator.push(
              MaterialPageRoute(
                builder: (_) => PostDetailsPage(postData: post),
              ),
            );
          } catch (_) {
            await openNotificationsFallback();
          }
          return true;

        case 'FRIEND_REQUEST':
          final targetUserId = actorId.isNotEmpty ? actorId : entityId;
          if (targetUserId.isEmpty) {
            await openNotificationsFallback();
            return true;
          }
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => ProfilePage(userId: targetUserId),
            ),
          );
          return true;

        case 'FRIEND_REQUEST_ACCEPTED':
          final targetUserId = actorId.isNotEmpty ? actorId : entityId;
          if (targetUserId.isEmpty) {
            await openNotificationsFallback();
            return true;
          }
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => ProfilePage(userId: targetUserId),
            ),
          );
          return true;

        default:
          await openNotificationsFallback();
          return true;
      }
    } finally {
      _isTapRoutingInProgress = false;
    }
  }
}

final notificationProvider =
    NotifierProvider<NotificationController, NotificationState>(
      NotificationController.new,
    );
