import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/models/chat.dart';
import 'package:studently/repositories/chat.dart';
import 'package:studently/services/socket.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/services/chat_presence.dart';
import 'package:studently/logger.dart';
import 'package:studently/providers/cache_freshness_provider.dart';
import 'package:studently/services/storage.dart';
import 'dart:async';

// 1. The State Object
class ChatState {
  final List<ChatConversation> conversations;
  final List<ChatMessage> activeMessages;
  final String? activeConversationId;
  final bool isLoading;
  final Map<String, String> userNames;
  final Map<String, String> userPics;
  final bool isBootstrapping;

  ChatState({
    this.conversations = const [],
    this.activeMessages = const [],
    this.activeConversationId,
    this.isLoading = false,
    this.userNames = const {},
    this.userPics = const {},
    this.isBootstrapping = false,
  });

  ChatState copyWith({
    List<ChatConversation>? conversations,
    List<ChatMessage>? activeMessages,
    String? activeConversationId,
    bool? isLoading,
    Map<String, String>? userNames,
    Map<String, String>? userPics,
    bool? isBootstrapping,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      activeMessages: activeMessages ?? this.activeMessages,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      isLoading: isLoading ?? this.isLoading,
      userNames: userNames ?? this.userNames,
      userPics: userPics ?? this.userPics,
      isBootstrapping: isBootstrapping ?? this.isBootstrapping,
    );
  }
}

// 2. The Provider class using Notifier (Unified for Riverpod 3.0)
class ChatNotifier extends Notifier<ChatState> {
  final ChatRepository _chatRepo = ChatRepository();
  final _chatStorage = StorageService().chatStorage;
  late final AppLifecycleListener _lifecycleListener;
  StreamSubscription? _socketSubscription;
  Timer? _userPicsRefreshTimer; // Timer for periodic refresh of user pictures

  // Tracks conversations the user has explicitly opened (and zeroed) in THIS session.
  // Only these get the "trust local zero" treatment in fetchConversations().
  final Set<String> _sessionZeroedConvIds = {};

  // FIXED: Forcefully clears the active ID using the constructor to bypass copyWith null-trap
  void clearActiveChat() {
    ChatPresence.setActiveConversation(null);
    state = ChatState(
      conversations: state.conversations,
      activeMessages: const [],
      activeConversationId: null,
      isLoading: false,
      userNames: state.userNames,
      userPics: state.userPics,
    );
  }

  @override
  ChatState build() {
    // 2. Setup the AppLifecycleListener for background tracking
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        logger.i(
          "[ChatProvider] App Resumed - Reconnecting WebSocket & Catching Up",
        );
        socketService.connect();
        fetchConversations();
        if (state.activeConversationId != null) {
          loadMessagesForChat(state.activeConversationId!);
        }
      },
      onPause: () {
        logger.i(
          "[ChatProvider] App Paused - Disconnecting WebSocket to save battery",
        );
        socketService.disconnect();
      },
    );

    // 3. Clean up the listener and SOCKET when the provider is destroyed
    ref.onDispose(() {
      logger.i("[ChatProvider] Provider Disposed - Closing WebSocket");
      ChatPresence.setActiveConversation(null);
      _lifecycleListener.dispose();
      _socketSubscription?.cancel(); // Unplug the listener
      _userPicsRefreshTimer?.cancel(); // Cancel periodic refresh timer
      socketService.disconnect();
    });

    _listenToCacheEvents();

    // 4. Initialize API and Socket connection
    Future.microtask(() => _init());

    return ChatState();
  }

  Future<void> _init() async {
    state = state.copyWith(isBootstrapping: true);
    _loadNamesFromHive();
    await _loadConversationsFromHive();
    await fetchConversations();

    socketService.connect();
    _initSocketListener();
    
    // Start periodic refresh of user pictures (similar to feed's silentRefresh)
    _startUserPicsRefreshTimer();
    state = state.copyWith(isBootstrapping: false);
  }

  void _listenToCacheEvents() {
    ref.listen<int>(cacheInvalidationBusProvider, (_, _) {
      final event = ref.read(cacheInvalidationBusProvider.notifier).latest();
      if (event == null) return;
      if (event.type == 'profile_photo_updated' ||
          event.type == 'profile_photo_removed' ||
          event.type == 'profile_updated' ||
          event.type == 'friendship_changed') {
        ref.read(cacheCoordinatorProvider).invalidate(CacheDomain.chatUserProfiles);
        _refreshAllUserPicturesFromServer(force: true);
      } else if (event.type == 'chat_state_changed') {
        ref.read(cacheCoordinatorProvider).invalidate(CacheDomain.chatConversations);
        fetchConversations();
      }
    });
  }

  /// Start a timer that periodically refreshes user pictures
  /// This mirrors the feed provider's silentRefresh pattern
  void _startUserPicsRefreshTimer() {
    _userPicsRefreshTimer?.cancel();
    _userPicsRefreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _refreshAllUserPicturesFromServer();
    });
  }

  /// Refresh all user pictures from the server without blocking UI
  /// This is called periodically to ensure profile picture updates are shown
  Future<void> _refreshAllUserPicturesFromServer({bool force = false}) async {
    final cache = ref.read(cacheCoordinatorProvider);
    if (!force && !cache.isStale(CacheDomain.chatUserProfiles)) return;
    if (!cache.tryBeginRefresh(CacheDomain.chatUserProfiles)) return;
    final convos = state.conversations;
    if (convos.isEmpty) {
      cache.endRefresh(CacheDomain.chatUserProfiles, success: true);
      return;
    }

    final myUid = authService.value.currentUser?.uid;
    final userIdsToFetch = <String>{};

    // Collect all user IDs from conversations
    for (final conv in convos) {
      if (!conv.isGroup) {
        for (final userId in conv.participants) {
          if (userId != myUid) {
            userIdsToFetch.add(userId);
          }
        }
      }
    }

    if (userIdsToFetch.isEmpty) {
      cache.endRefresh(CacheDomain.chatUserProfiles, success: true);
      return;
    }

    final updatedPics = Map<String, String>.from(state.userPics);
    final updatedNames = Map<String, String>.from(state.userNames);
    bool hasChanges = false;

    for (final userId in userIdsToFetch) {
      try {
        final profile = await _chatRepo.getUserProfileBasic(userId);
        final newName = profile['name'] ?? "Unknown User";
        final newPic = profile['picture'] ?? "";
        
        // Only update if changed (to avoid unnecessary UI rebuilds)
        if (updatedNames[userId] != newName || updatedPics[userId] != newPic) {
          updatedNames[userId] = newName;
          updatedPics[userId] = newPic;
          hasChanges = true;
        }
      } catch (e) {
        logger.w("[ChatProvider] Failed to refresh profile for $userId: $e");
      }
    }

    if (hasChanges) {
      state = state.copyWith(userNames: updatedNames, userPics: updatedPics);
      _chatStorage.saveUserNames(updatedNames);
      _chatStorage.saveUserPics(updatedPics);
      logger.i("[ChatProvider] Periodic refresh updated user pictures");
    }
    cache.endRefresh(CacheDomain.chatUserProfiles, success: true);
  }

  Future<String?> createOrGetConversation(String friendId) async {
    final existingChat = state.conversations
        .where((c) => !c.isGroup && c.participants.contains(friendId))
        .firstOrNull;

    if (existingChat != null) {
      logger.i("[ChatProvider] Chat exists locally, routing instantly!");
      return existingChat.id;
    }

    try {
      logger.i("[ChatProvider] Creating new chat on backend...");
      final newConvId = await _chatRepo.createOrGetConversation(friendId);
      if (newConvId != null) {
        fetchConversations();
      }
      return newConvId;
    } catch (e) {
      logger.e("[ChatProvider] Failed to create chat: $e");
      return null;
    }
  }

  // --- NAME CACHING LOGIC ---

  void _loadNamesFromHive() {
    final namesMap = _chatStorage.getCachedUserNames();
    final picsMap = _chatStorage.getCachedUserPics();
    if (namesMap.isNotEmpty || picsMap.isNotEmpty) {
      state = state.copyWith(userNames: namesMap, userPics: picsMap);
    }
  }

  Future<void> _fetchMissingNames(List<ChatConversation> convos) async {
    final myUid = authService.value.currentUser?.uid;
    final Set<String> missingIds = {};

    for (final conv in convos) {
      if (!conv.isGroup) {
        for (final id in conv.participants) {
          if (id != myUid && !state.userNames.containsKey(id)) {
            missingIds.add(id);
          }
        }
      }
    }

    if (missingIds.isEmpty) return;

    final updatedNames = Map<String, String>.from(state.userNames);
    final updatedPics = Map<String, String>.from(state.userPics);
    for (final id in missingIds) {
      try {
        final profile = await _chatRepo.getUserProfileBasic(id);
        updatedNames[id] = profile['name'] ?? "Unknown User";
        updatedPics[id] = profile['picture'] ?? "";
      } catch (e) {
        updatedNames[id] = "Unknown User";
        updatedPics[id] = "";
      }
    }

    state = state.copyWith(userNames: updatedNames, userPics: updatedPics);
    _chatStorage.saveUserNames(updatedNames);
    _chatStorage.saveUserPics(updatedPics);
  }

  // --- API & CACHING FOR CONVERSATIONS ---

  Future<void> _loadConversationsFromHive() async {
    final convos = _chatStorage.getCachedConversations();
    if (convos.isNotEmpty) {
      state = state.copyWith(conversations: convos);
      await _fetchMissingNames(convos);
    }
  }

  Future<void> fetchConversations() async {
    try {
      final convos = await _chatRepo.getUserConversations();

      // RACE CONDITION FIX: The API response arrives after we may have already
      // locally zeroed an unread count (when the user opened a chat). If we
      // blindly replace conversations, the server's stale non-zero count wins
      // and the badge reappears. For each conversation, keep whichever unread
      // count is lower — our local zero beats the server's stale positive count.
      final myUid = authService.value.currentUser?.uid;
      final mergedConvos = convos.map<ChatConversation>((serverConv) {
        if (myUid == null) return serverConv;

        final localConv = state.conversations
            .where((c) => c.id == serverConv.id)
            .firstOrNull;

        if (localConv == null) return serverConv;

        final serverCount = serverConv.unreadCounts[myUid] ?? 0;
        final localCount = localConv.unreadCounts[myUid] ?? 0;

        // Only trust the local zero when the user explicitly opened this chat
        // in the current app session. Hive-restored zeros (from a previous session)
        // must NOT override a fresh server count — that's what was causing unread
        // badges to disappear after re-launching the app.
        if (localCount < serverCount &&
            _sessionZeroedConvIds.contains(serverConv.id)) {
          return serverConv.copyWith(
            unreadCounts: Map<String, int>.from(serverConv.unreadCounts)
              ..[myUid] = localCount,
          );
        }
        return serverConv;
      }).toList();

      state = state.copyWith(conversations: mergedConvos);
      _chatStorage.saveConversations(mergedConvos);
      ref.read(cacheCoordinatorProvider).markFresh(CacheDomain.chatConversations);

      await _fetchMissingNames(mergedConvos);
    } catch (e) {
      logger.e("[ChatProvider] Error fetching conversations: $e");
    }
  }

  // --- API & CACHING FOR MESSAGES ---

  // Helper: zeros the unread count for [conversationId] in state and Hive.
  // Called in multiple places to guarantee the zero survives any race.
  void _zeroUnreadCount(String conversationId) {
    final myUid = authService.value.currentUser?.uid;
    if (myUid == null) return;

    // Mark this conv as explicitly zeroed in this session so fetchConversations()
    // knows to trust the local zero over the server's stale count.
    _sessionZeroedConvIds.add(conversationId);

    final updatedConvos = state.conversations.map<ChatConversation>((conv) {
      if (conv.id == conversationId) {
        final newCounts = Map<String, int>.from(conv.unreadCounts)..[myUid] = 0;
        return conv.copyWith(unreadCounts: newCounts);
      }
      return conv;
    }).toList();

    state = state.copyWith(conversations: updatedConvos);
    _chatStorage.saveConversations(updatedConvos);
  }

  Future<void> loadMessagesForChat(String conversationId) async {
    ChatPresence.setActiveConversation(conversationId);
    state = state.copyWith(
      activeConversationId: conversationId,
      isLoading: true,
    );

    // Zero the badge immediately so the UI updates right away.
    _zeroUnreadCount(conversationId);

    // Fire markAsRead to the backend. Don't await — let it run in background,
    // but the merge logic in fetchConversations protects our local zero anyway.
    _chatRepo.markChatAsRead(conversationId).catchError((e) {
      logger.e("[ChatProvider] Failed to mark as read on server: $e");
    });

    // Show cached messages instantly while the network request runs.
    final messages = _chatStorage.getCachedMessages(conversationId);
    state = state.copyWith(activeMessages: messages, isLoading: false);

    try {
      final freshMessages = await _chatRepo.getMessages(conversationId);
      if (state.activeConversationId == conversationId) {
        state = state.copyWith(activeMessages: freshMessages, isLoading: false);
        // Re-zero after the message fetch in case fetchConversations ran
        // concurrently and put a non-zero count back into state.
        _zeroUnreadCount(conversationId);
      }
      _chatStorage.saveMessages(conversationId, freshMessages);
    } catch (e) {
      logger.e("[ChatProvider] Error fetching messages: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  // --- SENDING MESSAGES & ATTACHMENTS ---

  Future<String?> uploadAttachment(List<int> bytes, String filename) async {
    try {
      return await _chatRepo.uploadAttachment(bytes, filename);
    } catch (e) {
      logger.e("[ChatProvider] Failed to upload attachment: $e");
      return null;
    }
  }

  Future<void> sendMessage(String text, {List<String>? attachments}) async {
    final convoId = state.activeConversationId;
    if (convoId == null) return;

    final currentUser = authService.value.currentUser;
    if (currentUser == null) return;

    final tempMsg = ChatMessage(
      id: "temp_${DateTime.now().millisecondsSinceEpoch}",
      conversationId: convoId,
      senderId: currentUser.uid,
      senderName: currentUser.displayName ?? "Me",
      text: text,
      attachments: attachments,
      timestamp: DateTime.now().toUtc().toIso8601String(),
    );

    final updatedMessages = List<ChatMessage>.from(state.activeMessages)
      ..add(tempMsg);
    state = state.copyWith(activeMessages: updatedMessages);

    try {
      await _chatRepo.sendMessage(
        conversationId: convoId,
        text: text,
        attachments: attachments,
      );
    } catch (e) {
      logger.e("[ChatProvider] Failed to send message: $e");
    }
  }

  // --- WEBSOCKET LISTENER ---

  void _initSocketListener() {
    _socketSubscription = socketService.stream.listen((rawMessage) {
      try {
        final payload = jsonDecode(rawMessage);
        if (payload['type'] == 'NEW_MESSAGE') {
          final incomingMessage = ChatMessage.fromJson(payload['data']);
          _handleIncomingMessage(incomingMessage);
        }
      } catch (e) {
        logger.e("[ChatProvider] Error parsing socket message: $e");
      }
    });
  }

  void _handleIncomingMessage(ChatMessage message) {
    if (state.activeConversationId == message.conversationId) {
      final filteredMessages = state.activeMessages
          .where((m) => !m.id.startsWith("temp_"))
          .toList();
      filteredMessages.add(message);
      state = state.copyWith(activeMessages: filteredMessages);
      _chatStorage.saveMessages(message.conversationId, filteredMessages);
      _chatRepo.markChatAsRead(message.conversationId).catchError((_) {});
    }

    final updatedConvos = state.conversations.map<ChatConversation>((conv) {
      if (conv.id == message.conversationId) {
        final myUid = authService.value.currentUser?.uid ?? '';

        // FIX: Build new unreadCounts immutably so Riverpod detects the diff.
        Map<String, int> newCounts = Map<String, int>.from(conv.unreadCounts);

        // Only increment unread if this chat is NOT currently open AND the
        // message is from someone else (covers both DMs and group chats).
        if (state.activeConversationId != message.conversationId &&
            message.senderId != myUid) {
          final current = newCounts[myUid] ?? 0;
          newCounts[myUid] = current + 1;
        }

        return conv.copyWith(
          lastMessage: message.toJson(),
          unreadCounts: newCounts,
        );
      }
      return conv;
    }).toList();

    final targetConvIndex = updatedConvos.indexWhere(
      (c) => c.id == message.conversationId,
    );
    if (targetConvIndex != -1) {
      final targetConv = updatedConvos.removeAt(targetConvIndex);
      updatedConvos.insert(0, targetConv);
    }

    state = state.copyWith(conversations: updatedConvos);
    _chatStorage.saveConversations(updatedConvos);
  }

  /// Refresh a specific user's profile picture when they update their profile photo
  /// Called by auth provider when a user updates their profile picture
  /// This ensures the new profile pic shows up immediately in DM active chats and new chat list
  void refreshUserPicture(String userId, String newPhotoUrl) {
    final updatedPics = Map<String, String>.from(state.userPics);
    updatedPics[userId] = newPhotoUrl;
    state = state.copyWith(userPics: updatedPics);
    _chatStorage.saveUserPics(updatedPics);
    ref.read(cacheCoordinatorProvider).invalidate(CacheDomain.chatUserProfiles);
    logger.i("[ChatProvider] Updated cached picture for user $userId");
  }

  /// Refresh all user pictures from the server
  /// Useful when multiple users' profiles might have changed
  Future<void> refreshAllUserPictures() async {
    final convos = state.conversations;
    if (convos.isEmpty) return;

    final myUid = authService.value.currentUser?.uid;
    final updatedPics = Map<String, String>.from(state.userPics);
    final updatedNames = Map<String, String>.from(state.userNames);
    bool hasChanges = false;

    for (final conv in convos) {
      if (!conv.isGroup) {
        for (final userId in conv.participants) {
          if (userId != myUid && !updatedPics.containsKey(userId)) {
            try {
              final profile = await _chatRepo.getUserProfileBasic(userId);
              updatedNames[userId] = profile['name'] ?? "Unknown User";
              updatedPics[userId] = profile['picture'] ?? "";
              hasChanges = true;
            } catch (e) {
              logger.w("[ChatProvider] Failed to fetch profile for $userId: $e");
            }
          }
        }
      }
    }

    if (hasChanges) {
      state = state.copyWith(userNames: updatedNames, userPics: updatedPics);
      _chatStorage.saveUserNames(updatedNames);
      _chatStorage.saveUserPics(updatedPics);
      logger.i("[ChatProvider] Refreshed all user pictures");
    }
  }

  /// Refresh a specific user's picture immediately from the server
  /// Called when a user's profile picture has been updated
  /// This ensures the change is reflected in both active chats and the friends list
  Future<void> refreshUserPictureFromServer(String userId) async {
    final cache = ref.read(cacheCoordinatorProvider);
    if (!cache.tryBeginRefresh(CacheDomain.chatUserProfiles, scopeId: userId)) return;
    try {
      final profile = await _chatRepo.getUserProfileBasic(userId);
      final newPic = profile['picture'] ?? "";
      final newName = profile['name'] ?? "Unknown User";
      
      final updatedPics = Map<String, String>.from(state.userPics);
      final updatedNames = Map<String, String>.from(state.userNames);
      
      updatedPics[userId] = newPic;
      updatedNames[userId] = newName;
      
      state = state.copyWith(userNames: updatedNames, userPics: updatedPics);
      _chatStorage.saveUserNames(updatedNames);
      _chatStorage.saveUserPics(updatedPics);
      cache.endRefresh(CacheDomain.chatUserProfiles, scopeId: userId, success: true);
      
      logger.i("[ChatProvider] Refreshed picture for user $userId from server");
    } catch (e) {
      cache.endRefresh(CacheDomain.chatUserProfiles, scopeId: userId, success: false);
      logger.w("[ChatProvider] Failed to refresh picture for $userId: $e");
    }
  }
}

final chatProvider = NotifierProvider.autoDispose<ChatNotifier, ChatState>(() {
  return ChatNotifier();
});
