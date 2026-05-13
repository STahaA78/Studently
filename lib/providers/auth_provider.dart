import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

class AuthNotifier extends AsyncNotifier<User?> {
  final _authStorage = StorageService().authStorage;

  List<Map<String, String>> friendsList = [];

  @override
  Future<User?> build() async {
    logger.i(
      "[$runtimeType] build() started - Checking local disk and Firebase",
    );

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

        return cachedUser;
      }

      // No cache found, but logged into Firebase: Fetch fresh from FastAPI
      final freshUser = await _fetchAndSaveFreshProfile(firebaseUser.uid);
      ref.read(cacheCoordinatorProvider).markFresh(CacheDomain.userProfile);

      await _ensureUserStorageInitialized();

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

  // --- Helper Methods ---

  Future<User> _fetchAndSaveFreshProfile(String uid) async {
    final userRepo = ref.read(userRepositoryProvider);
    final freshUser = await userRepo.fetchUserProfile(
      userId: uid,
    ); // Fetch specific user's profile

    // 4. Synchronous write to Hive
    _authStorage.saveUser(freshUser);
    return freshUser;
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
        // User cancelled Google sign-in
        state = AsyncValue.error(
          Exception("Google sign-in cancelled"),
          StackTrace.current,
        );
        return;
      }

      logger.d(
        "[$runtimeType] Firebase Google signin successful: ${firebaseUser.email}",
      );

      if (firebaseUser.email == null) {
        throw Exception("Google account does not have an email associated.");
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
                "Your email domain is not authorized for signup. Please use your organization email.",
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
      } catch (e) {
        logger.e("[$runtimeType] Email validation error", error: e);
        await authService.value.signOut();
        state = AsyncValue.error(e, StackTrace.current);
        return;
      }

      // Step 3: Call /profile endpoint to check if user exists
      final userRepo = ref.read(userRepositoryProvider);

      try {
        // Try to fetch user profile - this determines if user exists
        final user = await userRepo
            .fetchUserProfile(); // Uses default "0" for logged-in user

        // Step 4a: User exists in backend - save profile and login
        logger.i("[$runtimeType] Existing user detected: ${user.email}");
        _authStorage.saveUser(user);

        await _ensureUserStorageInitialized();

        state = AsyncValue.data(user);
      } catch (e) {
        // Step 4b: User doesn't exist in backend (404 or error)
        // Check if error indicates user not found
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('404') || errorString.contains('not found')) {
          logger.i(
            "[$runtimeType] New user detected (404), routing to signup...",
          );
          // Set signup flag to track incomplete signup flow
          setSignupInProgress(true);
          // Firebase user is available via authService.value.currentUser
          // State is set to null which will trigger SignupBasicPage
          state = AsyncValue.data(null);
        } else {
          // Other errors should be reported
          logger.e("[$runtimeType] Error checking user profile", error: e);
          await authService.value.signOut();
          state = AsyncValue.error(
            Exception("Failed to verify account. Please try again."),
            StackTrace.current,
          );
        }
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
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signUp({
    required String name,
    required String birthday,
    required Department department,
    required String batch,
    required List<Interest> interests,
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
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> logout() async {
    logger.i("[$runtimeType] Logging out...");

    // Clear user-specific storage before signing out
    try {
      final storageService = StorageService();
      await storageService.clearUserStorage();
      logger.i("[$runtimeType] User storage cleared");
    } catch (e) {
      logger.w("[$runtimeType] Error clearing user storage: $e");
      // Continue even if clearing fails
    }

    await authService.value.signOut();

    // 5. Delete from Hive
    _authStorage.clearUser();
    _authStorage.clearFriendsList(); // Also wipe friends list on logout
    _authStorage.clearInSignupFlow(); // Clear signup flag on logout
    friendsList.clear();
    final cache = ref.read(cacheCoordinatorProvider);
    cache.invalidateMany([
      (CacheDomain.userProfile, null),
      (CacheDomain.friendsList, null),
      (CacheDomain.chatUserProfiles, null),
    ]);

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
        name: updatedData['name'] ?? currentUser.name,
        department: updatedDepartment ?? currentUser.department,
        batch: updatedData['batch'] ?? currentUser.batch,
        interests: updatedData['interests'] != null
            ? List<Interest>.from(updatedData['interests'])
            : currentUser.interests,
        friendsCount: currentUser.friendsCount,
        university: currentUser.university,
      );

      // 3. Update RAM and Disk instantly
      state = AsyncValue.data(updatedUser);
      _authStorage.saveUser(updatedUser);
      final cache = ref.read(cacheCoordinatorProvider);
      cache.markFresh(CacheDomain.userProfile);
      ref.read(cacheInvalidationBusProvider.notifier).publish(
        CacheInvalidationEvent(type: 'profile_updated', userId: updatedUser.id),
      );
    }
  }

  Future<void> updateProfilePhoto({
    required String filePath,
    Uint8List? fileBytes,
    String? filename,
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
      );

      // 2. Fetch the updated profile with new photo URL from backend
      final firebaseUser = authService.value.currentUser;
      if (firebaseUser != null) {
        final updatedUser = await _fetchAndSaveFreshProfile(firebaseUser.uid);

        // 3. Clear CachedNetworkImage cache for old photo if it existed
        if (oldPhotoUrl != null && oldPhotoUrl.isNotEmpty) {
          await CachedNetworkImage.evictFromCache(oldPhotoUrl);
          logger.i("[$runtimeType] Cleared cache for old profile photo: $oldPhotoUrl");
        }

        // 4. Refresh friends list to get updated profile pictures from server
        await fetchFriendsList();

        // 5. Notify chat provider to refresh user pictures cache
        // This ensures the new profile pic shows up in DM active chats and new chat list
        if (updatedUser.picture != null && updatedUser.picture!.isNotEmpty) {
          await _notifyProfilePhotoUpdated(firebaseUser.uid, updatedUser.picture!);
        }
        ref.read(cacheCoordinatorProvider).markFresh(CacheDomain.userProfile);
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
        interests: currentUser.interests,
        picture: '', // Wipe the photo locally
        friendsCount: currentUser.friendsCount,
        university: currentUser.university,
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
        university: currentUser.university,
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
