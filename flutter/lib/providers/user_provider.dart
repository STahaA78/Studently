import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../repositories/user.dart';

class UserNotifier extends Notifier<User?> {
  @override
  User? build() {
    // Initial fetch of the logged-in user profile
    Future.microtask(() => fetchProfile());
    return null;
  }

  Future<void> fetchProfile() async {
    try {
      final user = await ref.read(userRepositoryProvider).fetchUserProfile("0");
      state = user;
    } catch (e) {
      state = null;
    }
  }

  void updateLocalUser(User updatedUser) {
    state = updatedUser;
  }
}

final userRepositoryProvider = Provider((ref) => UserRepository());

final userProvider = NotifierProvider<UserNotifier, User?>(() {
  return UserNotifier();
});
