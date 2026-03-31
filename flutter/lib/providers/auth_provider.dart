import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/services/firebase_auth.dart'; 
import 'package:studently/repositories/user.dart'; 
import 'package:studently/models/user.dart'; 
import 'package:studently/models/backend_config.dart'; 
import 'package:studently/logger.dart'; // <-- Imported your logger

// 1. Expose your Repository via Riverpod
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

// 2. The Auth State Manager
class AuthNotifier extends AsyncNotifier<User?> {
  
  @override
  Future<User?> build() async {
    logger.i("[$runtimeType] build() started - Checking for existing Firebase session");
    final firebaseUser = authService.value.currentUser;

    if (firebaseUser != null) {
      try {
        logger.d("[$runtimeType] Firebase user found (UID: ${firebaseUser.uid}). Fetching profile from backend...");
        final userRepo = ref.read(userRepositoryProvider);
        
        final userProfile = await userRepo.fetchUserProfile(firebaseUser.uid);
        logger.i("[$runtimeType] Profile fetched successfully for ${firebaseUser.uid}. User is logged in.");
        
        return userProfile;
      } catch (e, stackTrace) {
        logger.e("[$runtimeType] Failed to fetch profile during build. Logging out locally.", error: e, stackTrace: stackTrace);
        await logout();
        return null;
      }
    }
    
    logger.i("[$runtimeType] No existing session found. User is logged out.");
    return null; 
  }

  Future<void> login(String email, String password) async {
    logger.i("[$runtimeType] login() started for email: $email");
    state = const AsyncValue.loading();
    
    try {
      // 1. Log into Firebase 
      await authService.value.signIn(email: email, password: password);
      
      // 2. Verify Firebase User
      final firebaseUser = authService.value.currentUser;
      if (firebaseUser == null) throw Exception("Firebase login failed - currentUser is null");
      
      logger.d("[$runtimeType] Firebase login successful (UID: ${firebaseUser.uid}). Fetching backend profile...");

      // 3. Use the repository to fetch the Studently User Profile
      final userRepo = ref.read(userRepositoryProvider);
      final user = await userRepo.fetchUserProfile(firebaseUser.uid);
      
      logger.i("[$runtimeType] Backend profile fetched. login() completed successfully.");
      
      // 4. Update UI state instantly
      state = AsyncValue.data(user);
      
    } catch (e, stack) {
      logger.e("[$runtimeType] login() failed", error: e, stackTrace: stack);
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
    logger.i("[$runtimeType] signUp() started for email: $email");
    state = const AsyncValue.loading();
    
    try {
      // 1. Create Firebase Account
      await authService.value.createAccount(email: email, password: password);
      
      // 2. Verify Firebase User
      final firebaseUser = authService.value.currentUser;
      if (firebaseUser == null) throw Exception("Firebase signup failed - currentUser is null");

      logger.d("[$runtimeType] Firebase account created (UID: ${firebaseUser.uid}). Registering in backend...");

      // 3. Use the repository to handle the exact payload expected by FastAPI
      final userRepo = ref.read(userRepositoryProvider);
      final success = await userRepo.registerUser(
        uid: firebaseUser.uid,
        name: name,
        email: email,
        birthday: birthday,
        department: department,
        batch: batch,
        interests: interests,
      );
      
      if (success) {
        logger.d("[$runtimeType] Backend registration successful. Fetching new profile...");
        // Fetch the newly created profile so the app state has all default fields
        final user = await userRepo.fetchUserProfile(firebaseUser.uid);
        
        logger.i("[$runtimeType] signUp() completed successfully.");
        state = AsyncValue.data(user);
      } else {
        throw Exception("Backend registration returned false.");
      }
      
    } catch (e, stack) {
      logger.e("[$runtimeType] signUp() failed", error: e, stackTrace: stack);
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> logout() async {
    logger.i("[$runtimeType] logout() started");
    try {
      await authService.value.signOut();
      state = const AsyncValue.data(null);
      logger.i("[$runtimeType] logout() completed successfully");
    } catch (e, stack) {
      logger.e("[$runtimeType] logout() failed", error: e, stackTrace: stack);
      // Even if it fails, we usually want to clear the local state so the user isn't stuck
      state = const AsyncValue.data(null);
    }
  }
}

// 3. The provider your UI screens will actually watch
final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(() {
  return AuthNotifier();
});