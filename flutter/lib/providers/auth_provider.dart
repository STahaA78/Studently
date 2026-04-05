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
  
  List<Map<String, String>> friendsList = [];
  
  @override
  Future<User?> build() async {
    logger.i("[$runtimeType] build() started - Checking local disk and Firebase");
    
    // 2. Synchronous read from Hive (No await needed!)
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

    // 3. Check Firebase session
    final firebaseUser = authService.value.currentUser;

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
    final freshUser = await userRepo.fetchUserProfile(uid);
    
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

  Future<void> login(String email, String password) async {
    state = const AsyncValue<User?>.loading();
    try {
      await authService.value.signIn(email: email, password: password);
      final firebaseUser = authService.value.currentUser;
      
      final user = await _fetchAndSaveFreshProfile(firebaseUser!.uid);
      state = AsyncValue.data(user);
      
    } catch (e, stack) {
      logger.e("[$runtimeType] Login failed", error: e, stackTrace: stack);
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signUp({
    required String email, 
    required String password, 
    required String name,
    required String birthday, 
    required String department,
    required String batch,
    required List<Interest> interests, 
  }) async {
    state = const AsyncValue<User?>.loading();
    try {
      await authService.value.createAccount(email: email, password: password);
      final firebaseUser = authService.value.currentUser;

      final userRepo = ref.read(userRepositoryProvider);
      final success = await userRepo.registerUser(
        uid: firebaseUser!.uid,
        name: name,
        email: email,
        birthday: birthday,
        department: department,
        batch: batch,
        interests: interests,
      );
      
      if (success) {
        final user = await _fetchAndSaveFreshProfile(firebaseUser.uid);
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
    friendsList.clear();

    state = const AsyncValue.data(null);
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
        profilePhotoUrl: currentUser.profilePhotoUrl, 
        name: updatedData['name'] ?? currentUser.name,
        department: updatedData['department'] ?? currentUser.department,
        batch: updatedData['batch'] ?? currentUser.batch,
        interests: updatedData['interests'] != null 
            ? List<Interest>.from(updatedData['interests']) 
            : currentUser.interests,
        friendsCount: currentUser.friendsCount,
        university: currentUser.university,
        bio: currentUser.bio,
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
        profilePhotoUrl: '', // Wipe the photo locally
        friendsCount: currentUser.friendsCount,
        university: currentUser.university,
        bio: currentUser.bio,
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
        profilePhotoUrl: currentUser.profilePhotoUrl,
        friendsCount: (currentUser.friendsCount ?? 0) + 1, // Instantly +1
        university: currentUser.university,
        bio: currentUser.bio,
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