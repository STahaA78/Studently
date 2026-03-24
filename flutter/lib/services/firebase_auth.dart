import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:studently/logger.dart';

ValueNotifier<AuthService> authService = ValueNotifier(AuthService());

class AuthService {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;

  User? get currentUser => firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => firebaseAuth.authStateChanges();

  // Future<User?> signIn({
  //   required String email,
  //   required String password,
  // }) async {
  //   logger.i("[$runtimeType] SignIn Started");
  //   logger.d("[$runtimeType] Email: $email, Password: $password");
  //   try {
  //     final userCredential = await firebaseAuth.signInWithEmailAndPassword(
  //       email: email,
  //       password: password
  //     );
  //     logger.i("[$runtimeType] SignIn Successful");
  //     return userCredential.user;
  //   } catch (e) {
  //     logger.e("[$runtimeType] SignIn Failed" , error: e);
  //     rethrow;
  //   }
  // }
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {

    logger.i("[$runtimeType] SignIn Started");

    try {

      final userCredential = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password
      );

      //final token = await userCredential.user?.getIdToken(true);      

      logger.i("[$runtimeType] SignIn Successful");

      return userCredential.user;

    } catch (e) {

      logger.e("[$runtimeType] SignIn Failed", error: e);
      rethrow;

    }
  }
  Future<User?> createAccount({
    required String email,
    required String password,
  }) async {
    logger.i("[$runtimeType] CreateAccount Started");
    logger.d("[$runtimeType] Email: $email, Password: $password");
    try {
      final userCredential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password
      );
      logger.i("[$runtimeType] CreateAccount Successful");
      return userCredential.user;
    } catch (e) {
      logger.e("[$runtimeType] CreateAccount Failed" , error: e);
      rethrow;
    }
  }

  Future<void> signOut() async {
    logger.i("[$runtimeType] SignOut Started");
    try {
      await firebaseAuth.signOut();
      logger.i("[$runtimeType] SignOut Successful");
    } catch (e) {
      logger.e("[$runtimeType] SignOut Failed" , error: e);
      rethrow;
    }
  }
  
  Future<void> resetPassword({
    required String email
  }) async {
    logger.i("[$runtimeType] ResetPassword Started");
    logger.d("[$runtimeType] Email: $email");
    try {
      await firebaseAuth.sendPasswordResetEmail(email: email);
      logger.i("[$runtimeType] ResetPassword Successful");
    } catch (e) {
      logger.e("[$runtimeType] ResetPassword Failed" , error: e);
      rethrow;
    }
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    logger.i("[$runtimeType] DeleteAccount Started");
    logger.d("[$runtimeType] Email: $email , Password: $password");
    AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: password
    );
    try {
      await currentUser?.reauthenticateWithCredential(credential);
      await currentUser?.delete();
      await firebaseAuth.signOut();
      logger.i("[$runtimeType] DeleteAccount Successful");
    } catch (e) {
      logger.e("[$runtimeType] DeleteAccount Failed" , error: e);
      rethrow;
    }
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    logger.i("[$runtimeType] UpdatePassword Started");
    logger.d("[$runtimeType] Current Password: $currentPassword , New Password: $newPassword");
    AuthCredential credential = EmailAuthProvider.credential(
      email: currentUser?.email ?? '',
      password: currentPassword
    );
    try {
      await currentUser?.reauthenticateWithCredential(credential);
      await currentUser?.updatePassword(newPassword);
      logger.i("[$runtimeType] UpdatePassword Successful");
    } catch (e) {
      logger.e("[$runtimeType] UpdatePassword Failed" , error: e);
      rethrow;
    }
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    logger.i("[$runtimeType] GetIdToken Started");
    logger.d("[$runtimeType] Force Refresh: $forceRefresh");
    
    try {
      final user = firebaseAuth.currentUser;
      
      if (user == null) {
        logger.w("[$runtimeType] GetIdToken Failed: No user currently signed in");
        return null;
      }

      final String? token = await user.getIdToken(forceRefresh);
      
      if (token != null) {
        // Logging only the first few characters for security
        logger.i("[$runtimeType] GetIdToken Successful");
        logger.d("[$runtimeType] Token (Partial): ${token.substring(0, 10)}...");
      } else {
        logger.w("[$runtimeType] GetIdToken Successful but token was null");
      }

      return token;
    } catch (e) {
      logger.e("[$runtimeType] GetIdToken Failed", error: e);
      // We don't necessarily want to crash the app if token fetch fails, 
      // so we return null, but you could also rethrow if preferred.
      return null;
    }
  }
}