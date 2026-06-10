import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:studently/logger.dart';
import 'package:studently/config.dart';

ValueNotifier<AuthService> authService = ValueNotifier(AuthService());

class AuthService {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;

  GoogleSignIn _googleSignIn() {
    if (kIsWeb) {
      return GoogleSignIn(clientId: AppConfig.googleClientId);
    }

    return GoogleSignIn(serverClientId: AppConfig.googleClientId);
  }

  User? get currentUser => firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => firebaseAuth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    logger.i("[$runtimeType] SignInWithGoogle Started");
    try {
      final GoogleSignIn googleSignIn = _googleSignIn();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        logger.w("[$runtimeType] SignInWithGoogle cancelled by user");
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await firebaseAuth.signInWithCredential(
        credential,
      );

      logger.i("[$runtimeType] SignInWithGoogle Successful");
      logger.d("[$runtimeType] User: ${userCredential.user?.email}");

      return userCredential.user;
    } catch (e) {
      logger.e("[$runtimeType] SignInWithGoogle Failed", error: e);
      rethrow;
    }
  }

  Future<void> signOut() async {
    logger.i("[$runtimeType] SignOut Started");
    final GoogleSignIn googleSignIn = _googleSignIn();

    // On Android/iOS, Google cleanup can fail on some devices/ROMs.
    // Logout must still succeed, so we never let this block Firebase sign-out.
    try {
      await googleSignIn.signOut();
    } catch (e) {
      logger.w("[$runtimeType] Google signOut cleanup failed: $e");
    }

    try {
      await googleSignIn.disconnect();
    } catch (e) {
      logger.w("[$runtimeType] Google disconnect cleanup failed: $e");
    }

    try {
      await firebaseAuth.signOut();
      logger.i("[$runtimeType] SignOut Successful");
    } catch (e) {
      logger.e("[$runtimeType] Firebase signOut failed", error: e);
      rethrow;
    }
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    logger.i("[$runtimeType] GetIdToken Started");
    logger.d("[$runtimeType] Force Refresh: $forceRefresh");

    try {
      final user = firebaseAuth.currentUser;

      if (user == null) {
        logger.w(
          "[$runtimeType] GetIdToken Failed: No user currently signed in",
        );
        return null;
      }

      final String? token = await user.getIdToken(forceRefresh);

      if (token != null) {
        // Logging only the first few characters for security
        logger.i("[$runtimeType] GetIdToken Successful");
        logger.d(
          "[$runtimeType] Token (Partial): ${token.substring(0, 10)}...",
        );
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
