import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart'; // Replaced flutter_secure_storage
import 'package:studently/services/firebase_auth.dart'; 
import 'package:studently/repositories/user.dart'; 
import 'package:studently/models/user.dart'; 
import 'package:studently/models/backend_config.dart'; 
import 'package:studently/logger.dart';
import 'dart:typed_data';
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

class AuthNotifier extends AsyncNotifier<User?> {
  // 1. Initialize Hive box reference 
  // (Ensure Hive.openBox('authBox') is called in main.dart before the app runs)
  final _authBox = Hive.box('authBox');
  static const _userKey = 'cached_user_profile';
  static const _inSignupKey = 'in_signup_flow';
  
  List<Map<String, String>> friendsList = [];
  
  @override
  Future<User?> build() async {
    logger.i("[$runtimeType] build() started - Checking local disk and Firebase");
    
    // 2. Check if user is in incomplete signup flow
    final inSignupFlow = _authBox.get(_inSignupKey, defaultValue: false) as bool;
    final firebaseUser = authService.value.currentUser;
    
    if (inSignupFlow && firebaseUser != null) {
      // User is signed into Firebase but abandoned signup - clean up
      logger.w("[$runtimeType] User abandoned signup flow, signing out from Firebase");
      try {
        await authService.value.signOut();
      } catch (e) {
        logger.e("[$runtimeType] Error signing out abandoned signup user", error: e);
      }
      _authBox.delete(_inSignupKey);
      return null;
    }
    
    // 3. Synchronous read from Hive (No await needed!)
    final String? localJson = _authBox.get(_userKey);
    User? cachedUser;

    final cachedFriends = _authBox.get('friends_list');
    if (cachedFriends != null) {
      final List<dynamic> decoded = jsonDecode(cachedFriends);
      friendsList = decoded.map((e) => Map<String, String>.from(e)).toList();
    }
    
    if (localJson != null) {
      cachedUser = User.fromJson(jsonDecode(localJson));
      logger.d("[$runtimeType] Cached user found: ${cachedUser.name}");
    }

    // 4. Check Firebase session
    if (firebaseUser != null) {
      if (cachedUser != null) {
        // INSTANT UI: Return cached data but trigger a refresh in the background
        _refreshProfileInBackground(firebaseUser.uid);
        return cachedUser;
      }
      
      // No cache found, but logged into Firebase: Fetch fresh from FastAPI
      return await _fetchAndSaveFreshProfile(firebaseUser.uid);
    }
    
    return null; // Not logged in
  }

  // --- Helper Methods ---

  Future<User> _fetchAndSaveFreshProfile(String uid) async {
    final userRepo = ref.read(userRepositoryProvider);
    final freshUser = await userRepo.fetchUserProfile(userId: uid); // Fetch specific user's profile
    
    // 4. Synchronous write to Hive
    _authBox.put(_userKey, jsonEncode(freshUser.toJson()));
    return freshUser;
  }

  Future<void> _refreshProfileInBackground(String uid) async {
    try {
      final freshUser = await _fetchAndSaveFreshProfile(uid);
      state = AsyncValue.data(freshUser); // Update the state silently
      
      // Fetch and cache friends in the background
      await fetchFriendsList(); 
      
      logger.d("[$runtimeType] Background profile refresh complete");
    } catch (e) {
      logger.w("[$runtimeType] Background refresh failed: $e");
    }
  }

  // Dedicated method to fetch friends from UserRepository
  Future<void> fetchFriendsList() async {
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final rawFriends = await userRepo.getFriendsList(); 
      
      friendsList = rawFriends;
      _authBox.put('friends_list', jsonEncode(friendsList));
    } catch (e) {
      logger.e("[$runtimeType] Error fetching friends list: $e");
    }
  }

  // --- Actions ---

  /// Sign in with Google and check if user exists in backend
  /// If user exists -> fetch and login
  /// If user is new -> store Firebase user and signal for signup flow
  Future<void> signInWithGoogle() async {
    state = const AsyncValue<User?>.loading();
    try {
      // Step 1: Firebase authentication with Google
      final firebaseUser = await authService.value.signInWithGoogle();
      
      if (firebaseUser == null) {
        // User cancelled Google sign-in
        state = AsyncValue.error(Exception("Google sign-in cancelled"), StackTrace.current);
        return;
      }

      logger.d("[$runtimeType] Firebase Google signin successful: ${firebaseUser.email}");

      // Step 2: Call /profile endpoint to check if user exists
      final userRepo = ref.read(userRepositoryProvider);
      
      try {
        if (firebaseUser.email == null) {
          throw Exception("Google account does not have an email associated.");
        }

        // Try to fetch user profile - this determines if user exists
        final user = await userRepo.fetchUserProfile(); // Uses default "0" for logged-in user
        
        // Step 3a: User exists in backend - save profile and login
        logger.i("[$runtimeType] Existing user detected: ${user.email}");
        _authBox.put(_userKey, jsonEncode(user.toJson()));
        state = AsyncValue.data(user);
        
      } catch (e) {
        // Step 3b: User doesn't exist in backend (404 or error)
        // Check if error indicates user not found
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('404') || errorString.contains('not found')) {
          logger.i("[$runtimeType] New user detected (404), routing to signup...");
          // Set signup flag to track incomplete signup flow
          setSignupInProgress(true);
          // Firebase user is available via authService.value.currentUser
          // State is set to null which will trigger SignupBasicPage
          state = AsyncValue.data(null);
        } else {
          // Other errors should be reported
          logger.e("[$runtimeType] Error checking user profile", error: e);
          await authService.value.signOut();
          state = AsyncValue.error(Exception("Failed to verify account. Please try again."), StackTrace.current);
        }
      }
      
    } catch (e, stack) {
      logger.e("[$runtimeType] SignInWithGoogle failed", error: e, stackTrace: stack);
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
    required String department,
    required String batch,
    required List<Interest> interests, 
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
      );
      
      if (success) {
        final user = await _fetchAndSaveFreshProfile(firebaseUser.uid);
        // Clear signup flag after successful signup
        setSignupInProgress(false);
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
    await authService.value.signOut();
    
    // 5. Delete from Hive
    await _authBox.delete(_userKey); 
    await _authBox.delete('friends_list'); // Also wipe friends list on logout
    await _authBox.delete(_inSignupKey); // Clear signup flag on logout
    friendsList.clear();

    state = const AsyncValue.data(null);
  }

  /// Set signup flag to indicate user is in signup flow
  void setSignupInProgress(bool inProgress) {
    logger.i("[$runtimeType] Setting signup in progress: $inProgress");
    if (inProgress) {
      _authBox.put(_inSignupKey, true);
    } else {
      _authBox.delete(_inSignupKey);
    }
  }

  Future<void> updateProfile(Map<String, dynamic> updatedData) async {
    final userRepo = ref.read(userRepositoryProvider);
    
    // 1. Wait for FastAPI to confirm the save was successful
    await userRepo.updateUserProfile(updatedData);
    
    final currentUser = state.value;
    if (currentUser != null) {
      // 2. Locally merge the newly saved data with the existing profile
      final updatedUser = User(
        id: currentUser.id,
        email: currentUser.email,
        birthday: currentUser.birthday,
        picture: currentUser.picture,
        name: updatedData['name'] ?? currentUser.name,
        department: updatedData['department'] ?? currentUser.department,
        batch: updatedData['batch'] ?? currentUser.batch,
        interests: updatedData['interests'] != null 
            ? List<Interest>.from(updatedData['interests']) 
            : currentUser.interests,
        friendsCount: currentUser.friendsCount,
        university: currentUser.university,
      );

      // 3. Update RAM and Disk instantly
      state = AsyncValue.data(updatedUser);
      _authBox.put(_userKey, jsonEncode(updatedUser.toJson()));
    }
  }


  Future<void> updateProfilePhoto({
    required String filePath,
    Uint8List? fileBytes,
    String? filename,
  }) async {
    try {
      final userRepo = ref.read(userRepositoryProvider);
      
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
        
        // 3. Update state to trigger UI refresh with new profile photo
        state = AsyncValue.data(updatedUser);
        
        logger.i("[$runtimeType] Profile photo updated successfully");
      }
    } catch (e, stack) {
      logger.e("[$runtimeType] Profile photo upload failed", error: e, stackTrace: stack);
      rethrow; // Propagate error to UI for user feedback
    }
  }

  Future<void> removeProfilePhoto() async {
    final userRepo = ref.read(userRepositoryProvider);
    
    // 1. Wait for FastAPI to delete the file
    await userRepo.removeProfilePhoto();
    
    final currentUser = state.value;
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
      _authBox.put(_userKey, jsonEncode(updatedUser.toJson()));
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
      _authBox.put(_userKey, jsonEncode(updatedUser.toJson()));
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
      }

    } catch (e) {
      // 4. ROLLBACK: If API fails, revert state if we changed it
      logger.e("[$runtimeType] Failed to $action request. Rolling back.", error: e);
      
      if (action == 'accept') {
        state = AsyncValue.data(previousUser);
        _authBox.put(_userKey, jsonEncode(previousUser.toJson()));
      }
      
      throw Exception("Failed to $action friend request. Please try again."); 
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(() {
  return AuthNotifier();
});