import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Import storage
import 'package:studently/services/firebase_auth.dart'; 
import 'package:studently/repositories/user.dart'; 
import 'package:studently/models/user.dart'; 
import 'package:studently/models/backend_config.dart'; 
import 'package:studently/logger.dart';
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});
class AuthNotifier extends AsyncNotifier<User?> {
  // 1. Initialize Storage and Keys inside the provider
  final _storage = const FlutterSecureStorage();
  static const _userKey = 'cached_user_profile';

  @override
  Future<User?> build() async {
    logger.i("[$runtimeType] build() started - Checking local disk and Firebase");
    
    // 2. Try to get user from local disk first (for instant UI)
    final String? localJson = await _storage.read(key: _userKey);
    User? cachedUser;
    
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
    
    // Write to local disk
    await _storage.write(key: _userKey, value: jsonEncode(freshUser.toJson()));
    return freshUser;
  }

  Future<void> _refreshProfileInBackground(String uid) async {
    try {
      final freshUser = await _fetchAndSaveFreshProfile(uid);
      state = AsyncValue.data(freshUser); // Update the state silently
      logger.d("[$runtimeType] Background profile refresh complete");
    } catch (e) {
      logger.w("[$runtimeType] Background refresh failed: $e");
    }
  }

  // --- Actions ---

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
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
    state = const AsyncValue.loading();
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
    await _storage.delete(key: _userKey); // Clear the disk
    state = const AsyncValue.data(null);
  }

  Future<User?> updateProfile(Map<String, dynamic> updatedData) async {
    final userRepo = ref.read(userRepositoryProvider);
    
    // 1. Wait for FastAPI to confirm the save was successful
    await userRepo.updateUserProfile(updatedData); 
    
    final currentUser = state.value;
    if (currentUser != null) {
      // 2. Locally merge the newly saved data with the existing profile
      final updatedUser = User(
        id: currentUser.id,
        email: currentUser.email,
        password: currentUser.password,
        birthday: currentUser.birthday,
        profilePhotoUrl: currentUser.profilePhotoUrl, // Preserves the photo!
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
      await _storage.write(key: _userKey, value: jsonEncode(updatedUser.toJson()));
      return updatedUser;
    }
    return null;
  }


  Future<void> updateProfilePhoto(String imagePath) async {
    final userRepo = ref.read(userRepositoryProvider);
    await userRepo.uploadProfilePhoto(imagePath); // 1. POST
    
    final firebaseUser = authService.value.currentUser;
    if (firebaseUser != null) {
      await _refreshProfileInBackground(firebaseUser.uid); // 2. GET
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
        password: currentUser.password,
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
      await _storage.write(key: _userKey, value: jsonEncode(updatedUser.toJson()));
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(() {
  return AuthNotifier();
});