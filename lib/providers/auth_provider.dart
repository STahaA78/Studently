import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/repositories/user.dart';
import 'package:studently/models/user.dart';
import 'package:studently/models/backend_config.dart';
import 'package:studently/logger.dart';
import 'package:studently/providers/backend_config_provider.dart';
import 'package:studently/providers/cache_freshness_provider.dart';
import 'package:studently/providers/chat_provider.dart';
import 'package:studently/services/storage.dart';
import 'dart:typed_data';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

class AuthNotifier extends AsyncNotifier<User?> {
  final _authStorage = StorageService().authStorage;
  Timer? _cacheRefreshTimer;

  List<Map<String, String>> friendsList = [];

  @override
  Future<User?> build() async {
    logger.i(
      "[$runtimeType] build() started - Checking local disk and Firebase",
    );
    ref.onDispose(_cancelCacheRefreshTimer);

    // 2. Check if user is in incomplete signup flow
    final inSignupFlow = _authStorage.getInSignupFlow();
    final firebaseUser = authService.value.currentUser;

    if (inSignupFlow && firebaseUser != null) {
      // User is signed into Firebase but abandoned signup - clean up
      logger.w(
        "[$runtimeType] User abandoned signup flow, signing out from Firebase",
      );
      try {
        await authService.value.signOut();
      } catch (e) {
        logger.e(
          "[$runtimeType] Error signing out abandoned signup user",
          error: e,
        );
      }
      _authStorage.clearInSignupFlow();
      return null;
    }

    // 3. Synchronous read from Hive (No await needed!)
    User? cachedUser = _authStorage.getCachedUser();
    friendsList = _authStorage.getCachedFriends();

    if (cachedUser != null) {
      logger.d("[$runtimeType] Cached user found: ${cachedUser.name}");
    }

    // 4. Check Firebase session
    if (firebaseUser != null) {
      if (cachedUser != null) {
        await _ensureUserStorageInitialized();

        // INSTANT UI: Return cached data but trigger a refresh in the background
        final cache = ref.read(cacheCoordinatorProvider);
        if (cache.isStale(CacheDomain.userProfile)) {
          _refreshProfileInBackground(firebaseUser.uid);
        }
        if (cache.isStale(CacheDomain.friendsList)) {
          fetchFriendsList();
        }

        _startCacheRefreshChecks();

        return cachedUser;
      }

      // No cache found, but logged into Firebase: Fetch fresh from FastAPI
      final freshUser = await _fetchAndSaveFreshProfile(firebaseUser.uid);
      ref.read(cacheCoordinatorProvider).markFresh(CacheDomain.userProfile);

      await _ensureUserStorageInitialized();
      _startCacheRefreshChecks();

      return freshUser;
    }

    return null; // Not logged in
  }

  Future<void> _ensureUserStorageInitialized() async {
    try {
      final storageService = StorageService();
      if (!storageService.isUserStorageInitialized) {
        await storageService.initializeUserStorage();
        logger.i("[$runtimeType] User storage initialized");
      }
    } catch (e) {
      logger.w("[$runtimeType] Error initializing user storage: $e");
    }
  }

  void _cancelCacheRefreshTimer() {
    _cacheRefreshTimer?.cancel();
    _cacheRefreshTimer = null;
  }

  void _startCacheRefreshChecks() {
    if (_cacheRefreshTimer != null) return;

    _cacheRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final currentUser = authService.value.currentUser;
      if (currentUser == null) return;

      final cache = ref.read(cacheCoordinatorProvider);
      final profileStale = cache.isStale(CacheDomain.userProfile);
      final friendsStale = cache.isStale(CacheDomain.friendsList);

      logger.d(
        "[$runtimeType] Cache refresh tick profileStale=$profileStale friendsStale=$friendsStale",
      );

      if (profileStale) {
        await _refreshProfileInBackground(currentUser.uid);
      }
      if (friendsStale) {
        await fetchFriendsList();
      }
    });
  }

  // --- Helper Methods ---

  Future<User> _fetchAndSaveFreshProfile(String uid) async {
    final userRepo = ref.read(userRepositoryProvider);
    final profileResponse = await userRepo.fetchUserProfile(
      userId: uid,
    );

    if (!profileResponse.exists || profileResponse.data == null) {
      throw Exception("User profile not found");
    }

    final freshUser = profileResponse.data!;

    // 4. Synchronous write to Hive
    _authStorage.saveUser(freshUser);
    return freshUser;
  }

  Future<User> _waitForUpdatedPhotoProfile({
    required String uid,
    required String? previousPhotoUrl,
  }) async {
    final userRepo = ref.read(userRepositoryProvider);
    User? latestUser;

    for (int attempt = 0; attempt < 10; attempt++) {
      final response = await userRepo.fetchUserProfile(
        userId: uid
      );

      if (response.exists && response.data != null) {
        latestUser = response.data!;
        final oldUrl = (previousPhotoUrl ?? '').trim();
        final newUrl = (latestUser.picture ?? '').trim();

        // Wait until backend background processing publishes the new URL.
        final hasNewPhoto = oldUrl.isEmpty ? newUrl.isNotEmpty : (newUrl != oldUrl);
        if (hasNewPhoto) {
          _authStorage.saveUser(latestUser);
          return latestUser;
        }
      }

      await Future.delayed(const Duration(milliseconds: 450));
    }

    if (latestUser != null) {
      _authStorage.saveUser(latestUser);
      return latestUser;
    }

    throw Exception('Unable to fetch updated profile photo');
  }

  Future<void> _refreshProfileInBackground(String uid) async {
    final cache = ref.read(cacheCoordinatorProvider);
    if (!cache.tryBeginRefresh(CacheDomain.userProfile)) return;
    try {
      final freshUser = await _fetchAndSaveFreshProfile(uid);
      state = AsyncValue.data(freshUser); // Update the state silently
      cache.endRefresh(CacheDomain.userProfile, success: true);

      // Fetch and cache friends in the background
      await fetchFriendsList();

      logger.d("[$runtimeType] Background profile refresh complete");
    } catch (e) {
      cache.endRefresh(CacheDomain.userProfile, success: false);
      logger.w("[$runtimeType] Background refresh failed: $e");
    }
  }

  // Dedicated method to fetch friends from UserRepository
  Future<void> fetchFriendsList() async {
    final cache = ref.read(cacheCoordinatorProvider);
    if (!cache.tryBeginRefresh(CacheDomain.friendsList)) return;
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final rawFriends = await userRepo.getFriendsList();

      friendsList = rawFriends;
      _authStorage.saveFriendsList(friendsList);
      cache.endRefresh(CacheDomain.friendsList, success: true);
    } catch (e) {
      cache.endRefresh(CacheDomain.friendsList, success: false);
      logger.e("[$runtimeType] Error fetching friends list: $e");
    }
  }

  // --- Actions ---

  /// Sign in with Google and check if user exists in backend
  /// If user exists -> fetch and login
  /// If user is new -> store Firebase user and signal for signup flow
  /// Also validates email domain against allowed organizations
  Future<void> signInWithGoogle() async {
    state = const AsyncValue<User?>.loading();
    try {
      // Step 1: Firebase authentication with Google
      final firebaseUser = await authService.value.signInWithGoogle();

      if (firebaseUser == null) {
        logger.d("[$runtimeType] Google Sign-In cancelled by user");
        state = const AsyncValue.data(null);
        return;
      }

      logger.d(
        "[$runtimeType] Firebase Google signin successful: ${firebaseUser.email}",
      );

      if (firebaseUser.email == null) {
        logger.w("[$runtimeType] Google Sign-In did not return an email");
        logger.i("[$runtimeType] Signing out of Firebase due to missing email");
        await authService.value.signOut();
        state = const AsyncValue.data(null);
        return;
      }

      // Step 2: Validate email domain against allowed organizations
      try {
        final config = ref.read(backendConfigProvider);
        final email = firebaseUser.email!;
        final emailDomain = email.split('@').last.toLowerCase();

        logger.d("[$runtimeType] Validating email domain: $emailDomain");

        final isAllowed = config.whenData((cfg) {
          final allowed = cfg.allowedEmailDomains.any(
            (domain) => emailDomain.endsWith(domain.toLowerCase()),
          );

          if (!allowed) {
            logger.w(
              "[$runtimeType] Email domain not in allowed list: $emailDomain",
            );
          } else {
            logger.i("[$runtimeType] Email domain validated: $emailDomain");
          }

          return allowed;
        });

        // Check if domain validation passed
        await isAllowed.when(
          data: (allowed) {
            if (!allowed) {
              throw Exception(
                "Please use your university email to sign in.",
              );
            }
          },
          error: (error, stack) {
            logger.w("[$runtimeType] Could not validate email domain: $error");
            // Continue - backend will validate domain
          },
          loading: () {
            logger.w(
              "[$runtimeType] Config still loading, backend will validate domain",
            );
            // Continue - backend will validate domain
          },
        );
      } catch (e, stack) {
        logger.e("[$runtimeType] Email validation error", error: e);
        await authService.value.signOut();
        state = AsyncValue.error("Failed to validate email. Please try again.", stack);
        return;
      }

      // Step 3: Call /profile endpoint to check if user exists
      final userRepo = ref.read(userRepositoryProvider);

      // Fetch user profile envelope - the backend now returns 200 for both states.
      final profileResponse = await userRepo.fetchUserProfile();

      if (profileResponse.exists && profileResponse.data != null) {
        final user = profileResponse.data!;

        // Step 4a: User exists in backend - save profile and login
        logger.i("[$runtimeType] Existing user detected: ${user.email}");
        _authStorage.saveUser(user);

        await _ensureUserStorageInitialized();

        state = AsyncValue.data(user);
      } else {
        logger.i(
          "[$runtimeType] New user detected (profile missing), routing to signup...",
        );
        setSignupInProgress(true);
        state = AsyncValue.data(null);
      }
    } catch (e, stack) {
      logger.e(
        "[$runtimeType] SignInWithGoogle failed",
        error: e,
        stackTrace: stack,
      );
      // Make sure user is signed out on any error
      try {
        await authService.value.signOut();
      } catch (_) {}
      logger.e("[$runtimeType] Something went wrong during sign-in: $e");
      // Keep UI out of loading state without surfacing a generic error.
      state = AsyncValue.error(
        "An error occurred during sign-in. Please try again.",
        stack,
      );
    }
  }

  Future<void> signUp({
    required String name,
    required String birthday,
    required Department department,
    required String batch,
    required List<Interest> interests,
    Gender? gender,
    bool extractedFields = true,
  }) async {
    state = const AsyncValue<User?>.loading();
    try {
      final firebaseUser = authService.value.currentUser;
      if (firebaseUser == null) {
        throw Exception("No Firebase user found");
      }

      final userRepo = ref.read(userRepositoryProvider);
      final success = await userRepo.registerUser(
        uid: firebaseUser.uid,
        name: name,
        email: firebaseUser.email ?? '',
        birthday: birthday,
        department: department,
        batch: batch,
        interests: interests,
        gender: gender?.toApiString(),
        extractedFields: extractedFields,
      );

      if (success) {
        final user = await _fetchAndSaveFreshProfile(firebaseUser.uid);
        ref.read(cacheCoordinatorProvider).markFresh(CacheDomain.userProfile);
        // Clear signup flag after successful signup
        setSignupInProgress(false);

        await _ensureUserStorageInitialized();

        state = AsyncValue.data(user);
      } else {
        throw Exception("Backend registration failed");
      }
    } catch (e, stack) {
      logger.e("[$runtimeType] SignUp failed", error: e, stackTrace: stack);
      state = AsyncValue.error("Failed to sign up. Please try again.", stack);
    }
  }

  Future<void> logout() async {
    logger.i("[$runtimeType] Logging out...");

    // 1. Clear ALL local storage first (including user data and app config)
    try {
      final storageService = StorageService();
      await storageService.clearAllStorage();
      logger.i("[$runtimeType] All local storage cleared");
    } catch (e) {
      logger.w("[$runtimeType] Error clearing storage: $e");
    }

    // 2. Clear image cache to prevent the next user from seeing old profile pictures/posts
    try {
      await DefaultCacheManager().emptyCache();
      logger.i("[$runtimeType] Image cache cleared");
    } catch (e) {
      logger.w("[$runtimeType] Error clearing image cache: $e");
    }

    // 3. Clear all local RAM state and flags
    _authStorage.clearUser();
    _authStorage.clearFriendsList(); 
    _authStorage.clearInSignupFlow(); 
    friendsList.clear();
    final cache = ref.read(cacheCoordinatorProvider);
    cache.invalidateMany([
      (CacheDomain.userProfile, null),
      (CacheDomain.friendsList, null),
      (CacheDomain.chatUserProfiles, null),
    ]);

    // 4. Sign out of Firebase COMPLETELY before updating state
    await authService.value.signOut();

    // 5. Finally, set state to null to trigger UI refresh
    state = const AsyncValue.data(null);
  }

  /// Set signup flag to indicate user is in signup flow
  void setSignupInProgress(bool inProgress) {
    logger.i("[$runtimeType] Setting signup in progress: $inProgress");
    if (inProgress) {
      _authStorage.setInSignupFlow(true);
    } else {
      _authStorage.clearInSignupFlow();
    }
  }

  Future<void> updateProfile(Map<String, dynamic> updatedData) async {
    final userRepo = ref.read(userRepositoryProvider);

    // 1. Wait for FastAPI to confirm the save was successful
    await userRepo.updateUserProfile(updatedData);

    final currentUser = state.value;
    if (currentUser != null) {
      // Convert department data to Department object if provided
      Department? updatedDepartment;
      if (updatedData['department'] != null) {
        final deptData = updatedData['department'];
        if (deptData is Map<String, dynamic>) {
          updatedDepartment = Department(
            name: deptData['name'] ?? '',
            code: deptData['code'] ?? '',
          );
        } else if (deptData is Department) {
          updatedDepartment = deptData;
        }
      }

      // 2. Locally merge the newly saved data with the existing profile
      final updatedUser = User(
        id: currentUser.id,
        email: currentUser.email,
        birthday: currentUser.birthday,
        picture: currentUser.picture,
        thumbnail: currentUser.thumbnail,
        name: updatedData['name'] ?? currentUser.name,
        department: updatedDepartment ?? currentUser.department,
        batch: updatedData['batch'] ?? currentUser.batch,
        gender: currentUser.gender,
        interests: updatedData['interests'] != null
            ? List<Interest>.from(updatedData['interests'])
            : currentUser.interests,
        friendsCount: currentUser.friendsCount,
        postsCount: currentUser.postsCount,
        resourcesCount: currentUser.resourcesCount,
        university: currentUser.university,
        isPrivate: updatedData['is_private'] ?? currentUser.isPrivate,
      );

      // 3. Update RAM and Disk instantly
      state = AsyncValue.data(updatedUser);
      _authStorage.saveUser(updatedUser);
      final cache = ref.read(cacheCoordinatorProvider);
      cache.markFresh(CacheDomain.userProfile);
      _startCacheRefreshChecks();
      ref.read(cacheInvalidationBusProvider.notifier).publish(
        CacheInvalidationEvent(type: 'profile_updated', userId: updatedUser.id),
      );
    }
  }

  Future<void> updateProfilePhoto({
    required String filePath,
    Uint8List? fileBytes,
    String? filename,
    Map<String, dynamic>? cropData,
  }) async {
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final currentUser = state.value;
      final oldPhotoUrl = currentUser?.picture;

      // 1. Upload the photo to the backend
      await userRepo.uploadProfilePhoto(
        filePath: filePath,
        fileBytes: fileBytes,
        filename: filename,
        cropData: cropData,
      );

      // 2. Fetch the updated profile with new photo URL from backend
      final firebaseUser = authService.value.currentUser;
      if (firebaseUser != null) {
        final updatedUser = await _waitForUpdatedPhotoProfile(
          uid: firebaseUser.uid,
          previousPhotoUrl: oldPhotoUrl,
        );
        final newPhotoUrl = updatedUser.picture;

        // 3. Clear old cache only if URL changed.
        if (oldPhotoUrl != null &&
            oldPhotoUrl.isNotEmpty &&
            oldPhotoUrl != newPhotoUrl) {
          await CachedNetworkImage.evictFromCache(oldPhotoUrl);
          logger.i("[$runtimeType] Cleared cache for old profile photo: $oldPhotoUrl");
        }

        // Also evict current URL to avoid stale CDN/browser cache artifacts.
        if (newPhotoUrl != null && newPhotoUrl.isNotEmpty) {
          await CachedNetworkImage.evictFromCache(newPhotoUrl);
        }

        // 4. Refresh friends list to get updated profile pictures from server
        await fetchFriendsList();

        // 5. Notify chat provider to refresh user pictures cache
        // This ensures the new profile pic shows up in DM active chats and new chat list
        if (newPhotoUrl != null && newPhotoUrl.isNotEmpty) {
          await _notifyProfilePhotoUpdated(firebaseUser.uid, newPhotoUrl);
        }
        ref.read(cacheCoordinatorProvider).markFresh(CacheDomain.userProfile);
        _startCacheRefreshChecks();
        ref.read(cacheInvalidationBusProvider.notifier).publish(
          CacheInvalidationEvent(
            type: 'profile_photo_updated',
            userId: firebaseUser.uid,
          ),
        );

        // 6. Update state to trigger UI refresh with new profile photo
        state = AsyncValue.data(updatedUser);

        logger.i("[$runtimeType] Profile photo updated successfully - friends list refreshed");
      }
    } catch (e, stack) {
      logger.e(
        "[$runtimeType] Profile photo upload failed",
        error: e,
        stackTrace: stack,
      );
      rethrow; // Propagate error to UI for user feedback
    }
  }

  /// Notify the chat provider that a user's profile photo has been updated
  /// This ensures the DM page and new chat modal show the updated profile pictures
  Future<void> _notifyProfilePhotoUpdated(String userId, String newPhotoUrl) async {
    try {
      final chatNotifier = ref.read(chatProvider.notifier);
      // Optimistically update the in-memory cache so UI updates immediately
      chatNotifier.refreshUserPicture(userId, newPhotoUrl);

      // Also fetch the authoritative profile from server to ensure consistency
      // (handles cases where backend canonicalizes or rewrites the URL)
      await chatNotifier.refreshUserPictureFromServer(userId);

      logger.d("[$runtimeType] Notified chat provider about profile photo update for $userId");
    } catch (e) {
      logger.w("[$runtimeType] Could not notify chat provider: $e");
    }
  }

  Future<void> removeProfilePhoto() async {
    final userRepo = ref.read(userRepositoryProvider);
    final currentUser = state.value;
    final oldPhotoUrl = currentUser?.picture;

    // 1. Wait for FastAPI to delete the file
    await userRepo.removeProfilePhoto();

    if (currentUser != null) {
      // 2. Locally clear the photo URL string
      final updatedUser = User(
        id: currentUser.id,
        name: currentUser.name,
        email: currentUser.email,
        birthday: currentUser.birthday,
        department: currentUser.department,
        batch: currentUser.batch,
        gender: currentUser.gender,
        interests: currentUser.interests,
        picture: '', // Wipe the photo locally
        thumbnail: '',
        friendsCount: currentUser.friendsCount,
        postsCount: currentUser.postsCount,
        resourcesCount: currentUser.resourcesCount,
        university: currentUser.university,
        isPrivate: currentUser.isPrivate,
      );

      // 3. Update RAM and Disk
      state = AsyncValue.data(updatedUser);
      _authStorage.saveUser(updatedUser);

      // 4. Clear cached image for old URL if present
      if (oldPhotoUrl != null && oldPhotoUrl.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(oldPhotoUrl);
      }

      // 5. Refresh friends list and chat cache so DM + new chat modal reflect removal
      await fetchFriendsList();
      final firebaseUser = authService.value.currentUser;
      if (firebaseUser != null) {
        final chatNotifier = ref.read(chatProvider.notifier);
        chatNotifier.refreshUserPicture(firebaseUser.uid, '');
        await chatNotifier.refreshUserPictureFromServer(firebaseUser.uid);
        ref.read(cacheInvalidationBusProvider.notifier).publish(
          CacheInvalidationEvent(
            type: 'profile_photo_removed',
            userId: firebaseUser.uid,
          ),
        );
      }
    }
  }

  /// Explicitly refresh friends list (useful when profile pictures need to be updated)
  Future<void> refreshFriendsWithUpdatedPics() async {
    try {
      await fetchFriendsList();
      logger.i("[$runtimeType] Friends list refreshed with latest profile pictures");
    } catch (e) {
      logger.e("[$runtimeType] Failed to refresh friends list: $e");
    }
  }

  Future<void> respondToFriendRequest(String requesterId, String action) async {
    final currentUser = state.value;
    if (currentUser == null) return;

    // 1. Keep track of original state for rollback
    final previousUser = currentUser;

    // 2. OPTIMISTIC UPDATE: Only increment friend count if accepting
    if (action == 'accept') {
      final updatedUser = User(
        id: currentUser.id,
        name: currentUser.name,
        email: currentUser.email,
        birthday: currentUser.birthday,
        department: currentUser.department,
        batch: currentUser.batch,
        interests: currentUser.interests,
        picture: currentUser.picture,
        friendsCount: (currentUser.friendsCount ?? 0) + 1, // Instantly +1
        postsCount: currentUser.postsCount,
        resourcesCount: currentUser.resourcesCount,
        university: currentUser.university,
        isPrivate: currentUser.isPrivate,
      );

      // Apply to UI and Cache immediately
      state = AsyncValue.data(updatedUser);
      _authStorage.saveUser(updatedUser);
    }

    // 3. Send network request in the background
    try {
      final userRepo = ref.read(userRepositoryProvider);

      // Send dynamic action ('accept' or 'reject')
      await userRepo.respondRequest(requesterId, action);

      logger.i("[$runtimeType] Friend request $action on backend.");

      // NEW: If accepted, background refresh the friends list to ensure the chat modal gets updated!
      if (action == 'accept') {
        fetchFriendsList(); // Note: No await needed, let it update the cache silently!
        ref.read(cacheInvalidationBusProvider.notifier).publish(
          CacheInvalidationEvent(
            type: 'friendship_changed',
            userId: requesterId,
          ),
        );
      }
    } catch (e) {
      // 4. ROLLBACK: If API fails, revert state if we changed it
      logger.e(
        "[$runtimeType] Failed to $action request. Rolling back.",
        error: e,
      );

      if (action == 'accept') {
        state = AsyncValue.data(previousUser);
        _authStorage.saveUser(previousUser);
      }

      throw Exception("Failed to $action friend request. Please try again.");
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(() {
  return AuthNotifier();
});
