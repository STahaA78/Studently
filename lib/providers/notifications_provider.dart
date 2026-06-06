import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/logger.dart';
import 'package:studently/models/notifications.dart';
import 'package:studently/models/post.dart';
import 'package:studently/providers/cache_freshness_provider.dart';
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
  String? _lastHandledTapSignature;

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
    ref.listen<int>(cacheInvalidationBusProvider, (_, _) {
      final event = ref.read(cacheInvalidationBusProvider.notifier).latest();
      if (event == null) return;
      if (event.type == 'notification_state_changed') {
        ref
            .read(cacheCoordinatorProvider)
            .invalidate(CacheDomain.notifications);
        refreshFromServer();
      }
    });

    await _configureMessaging(uid);
    final cache = ref.read(cacheCoordinatorProvider);
    if (cache.isStale(CacheDomain.notifications)) {
      await refreshFromServer();
    }
    await processPendingTapIfAny();

    state = state.copyWith(isLoading: false, initialized: true);
  }

  Future<void> refreshFromServer() async {
    final cache = ref.read(cacheCoordinatorProvider);
    if (!cache.tryBeginRefresh(CacheDomain.notifications)) return;
    try {
      final fresh = await _repository.fetchNotifications(skip: 0, limit: 100);
      final visible = _filterVisibleNotifications(fresh);
      state = state.copyWith(notifications: visible);
      await _storage.saveNotifications(visible);
      cache.endRefresh(CacheDomain.notifications, success: true);
    } catch (e) {
      cache.endRefresh(CacheDomain.notifications, success: false);
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
    ref
        .read(cacheInvalidationBusProvider.notifier)
        .publish(
          const CacheInvalidationEvent(type: 'notification_state_changed'),
        );
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
    _lastHandledTapSignature = null;
    state = const NotificationState(notifications: []);
    await _storage.clearStorage();
    ref.read(cacheCoordinatorProvider).invalidate(CacheDomain.notifications);
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
    ref
        .read(cacheInvalidationBusProvider.notifier)
        .publish(
          const CacheInvalidationEvent(type: 'notification_state_changed'),
        );
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

    // 1. GET TOKEN FIRST (Crucial for Android to avoid SERVICE_NOT_AVAILABLE)
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _registeredToken = token;
        await _repository.registerFcmToken(token);
      }
    } catch (e) {
      logger.w('[NotificationController] Failed to get FCM token: $e');
    }

    // 2. SUBSCRIBE TO TOPIC ASYNCHRONOUSLY (Don't await, so it doesn't block listeners if it fails)
    if (!kIsWeb) {
      _messaging.subscribeToTopic("global_feed").catchError((e) {
        logger.w(
          '[NotificationController] Failed to subscribe to global_feed: $e',
        );
      });
    }

    // 3. SETUP LISTENERS
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
      _publishCacheEventsFromPayload(message.data);

      await _handleForegroundMessage(message);

      if (isActiveChatMessage && entityId != null) {
        _removeConversationMessageNotifications(entityId);
        try {
          await ChatRepository().markChatAsRead(entityId);
        } catch (_) {}
        return;
      }

      if (messageType == 'NEW_POST' ||
          messageType == 'NEW_COMMENT' ||
          messageType == 'POST_LIKE') {
        ref.read(feedProvider.notifier).silentRefresh();
      }

      await refreshFromServer();
    });

    _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) async {
      if (!_isSessionCompatible(uid)) return;
      _publishCacheEventsFromPayload(message.data);

      final messageType = message.data['type']?.toString();
      if (messageType == 'NEW_POST' ||
          messageType == 'NEW_COMMENT' ||
          messageType == 'POST_LIKE') {
        ref.read(feedProvider.notifier).silentRefresh();
      }
      await _routeByPayloadOrQueue(message.data);
      unawaited(refreshFromServer());
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null && _isSessionCompatible(uid)) {
      _publishCacheEventsFromPayload(initialMessage.data);
      final messageType = initialMessage.data['type']?.toString();
      if (messageType == 'NEW_POST' ||
          messageType == 'NEW_COMMENT' ||
          messageType == 'POST_LIKE') {
        Future.microtask(() => ref.read(feedProvider.notifier).silentRefresh());
      }

      await _routeByPayloadOrQueue(initialMessage.data);
      unawaited(refreshFromServer());
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
            await _routeByPayloadOrQueue(data);
            unawaited(refreshFromServer());
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
            unawaited(refreshFromServer());
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

    // Do NOT show foreground toast if it's a silent NEW_POST broadcast
    if (messageType == 'NEW_POST') {
      return;
    }

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
    _publishCacheEventsFromPayload(payload);
    _pendingTapPayload = payload;
    await processPendingTapIfAny();
  }

  void _publishCacheEventsFromPayload(Map<String, dynamic> payload) {
    final type = payload['type']?.toString() ?? '';
    final normalizedType = type.toUpperCase();
    final entityId = payload['entity_id']?.toString();
    final actorId = payload['actor_id']?.toString();
    final bus = ref.read(cacheInvalidationBusProvider.notifier);
    final cache = ref.read(cacheCoordinatorProvider);

    switch (normalizedType) {
      case 'NEW_POST':
      case 'NEW_COMMENT':
      case 'POST_LIKE':
      case 'POST_UNLIKE':
      case 'POST_LIKE_REMOVED':
      case 'COMMENT_DELETED':
      case 'COMMENT_REMOVED':
      case 'POST_DELETED':
      case 'POST_REMOVED':
        cache.invalidate(CacheDomain.feedPosts);
        bus.publish(const CacheInvalidationEvent(type: 'post_state_changed'));
        break;
      case 'NEW_MESSAGE':
        cache.invalidate(CacheDomain.chatConversations);
        bus.publish(const CacheInvalidationEvent(type: 'chat_state_changed'));
        break;
      case 'FRIEND_REQUEST':
      case 'FRIEND_REQUEST_ACCEPTED':
      case 'FRIEND_REQUEST_REJECTED':
      case 'FRIEND_REQUEST_DECLINED':
        cache.invalidate(CacheDomain.friendsList);
        cache.invalidate(CacheDomain.chatConversations);
        bus.publish(
          CacheInvalidationEvent(
            type: 'friendship_changed',
            userId: actorId ?? entityId,
          ),
        );
        break;
      case 'PROFILE_UPDATED':
      case 'PROFILE_PHOTO_UPDATED':
      case 'PROFILE_PHOTO_REMOVED':
        cache.invalidate(CacheDomain.userProfile);
        cache.invalidate(CacheDomain.friendsList);
        cache.invalidate(CacheDomain.chatUserProfiles);
        bus.publish(
          CacheInvalidationEvent(
            type: type == 'PROFILE_PHOTO_REMOVED'
                ? 'profile_photo_removed'
                : 'profile_photo_updated',
            userId: actorId ?? entityId,
          ),
        );
        break;
      case 'KNOWLEDGE_RESOURCE_UPLOADED':
      case 'KNOWLEDGE_RESOURCE_DELETED':
      case 'KNOWLEDGE_COURSE_UPDATED':
        final courseId = entityId;
        cache.invalidate(CacheDomain.knowledgeCourses);
        if (courseId != null && courseId.isNotEmpty) {
          cache.invalidate(
            CacheDomain.knowledgeCourseResources,
            scopeId: courseId,
          );
        } else {
          cache.invalidate(CacheDomain.knowledgeCourseResources);
        }
        bus.publish(
          CacheInvalidationEvent(type: type.toLowerCase(), courseId: courseId),
        );
        break;
      default:
        // Unknown push type: keep no-op to avoid accidental broad invalidation.
        break;
    }
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
    final signature = '$type|$payloadNotificationId|$entityId|$actorId';
    if (_lastHandledTapSignature == signature) {
      return true;
    }

    AppNotification? appNotification;
    if (payloadNotificationId.isNotEmpty) {
      appNotification = _findById(payloadNotificationId);
      if (appNotification != null) {
        unawaited(markAsRead(payloadNotificationId));
      } else {
        unawaited(
          refreshFromServer().then((_) async {
            await markAsRead(payloadNotificationId);
          }),
        );
      }
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
            _lastHandledTapSignature = signature;
            return true;
          }
          var otherUserName = 'Chat'; //
          // if (actorId.isNotEmpty) {
          // try {
          // otherUserName = await ChatRepository().getUserName(actorId);
          // } catch (_) {}
          // }
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => ChatPage(
                conversationId: entityId,
                otherUserId: actorId.isNotEmpty ? actorId : 'UNKNOWN',
                otherUserName: otherUserName,
              ),
            ),
          );
          _lastHandledTapSignature = signature;
          return true;

        case 'POST_LIKE':
        case 'NEW_COMMENT':
          if (entityId.isEmpty) {
            await openNotificationsFallback();
            _lastHandledTapSignature = signature;
            return true;
          }
          try {
            final repo = ref.read(postRepositoryProvider);
            Post? targetPost;

            // Prefer latest single-post fetch for deep links so comments/likes
            // are current even if feed cache is slightly behind.
            try {
              targetPost = await repo
                  .getPostById(entityId)
                  .timeout(const Duration(milliseconds: 1500));
              ref.read(feedProvider.notifier).updatePostLocally(targetPost);
            } catch (_) {
              // If details fetch fails/timeout, fall back to current feed cache.
              final currentFeed = ref.read(feedProvider).value ?? [];
              try {
                targetPost = currentFeed.firstWhere((p) => p.id == entityId);
              } catch (_) {}
            }

            if (targetPost == null) {
              await openNotificationsFallback();
              _lastHandledTapSignature = signature;
              return true;
            }

            await navigator.push(
              MaterialPageRoute(
                builder: (_) => PostDetailsPage(postData: targetPost!),
              ),
            );
            _lastHandledTapSignature = signature;
          } catch (_) {
            await openNotificationsFallback();
            _lastHandledTapSignature = signature;
          }
          return true;

        case 'FRIEND_REQUEST':
          final targetUserId = actorId.isNotEmpty ? actorId : entityId;
          if (targetUserId.isEmpty) {
            await openNotificationsFallback();
            _lastHandledTapSignature = signature;
            return true;
          }
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => ProfilePage(userId: targetUserId),
            ),
          );
          _lastHandledTapSignature = signature;
          return true;

        case 'FRIEND_REQUEST_ACCEPTED':
          final targetUserId = actorId.isNotEmpty ? actorId : entityId;
          if (targetUserId.isEmpty) {
            await openNotificationsFallback();
            _lastHandledTapSignature = signature;
            return true;
          }
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => ProfilePage(userId: targetUserId),
            ),
          );
          _lastHandledTapSignature = signature;
          return true;

        default:
          await openNotificationsFallback();
          _lastHandledTapSignature = signature;
          return true;
      }
    } finally {
      _isTapRoutingInProgress = false;
    }
  }

  // Future<void> _refreshFeedForPostTap() async {
  //   try {
  //     await ref
  //         .read(feedProvider.notifier)
  //         .silentRefresh()
  //         .timeout(const Duration(milliseconds: 1200));
  //   } catch (_) {
  //     // Timeout/failure should not block routing.
  //   }
  // }
}

final notificationProvider =
    NotifierProvider<NotificationController, NotificationState>(
      NotificationController.new,
    );
