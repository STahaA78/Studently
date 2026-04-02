import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import 'auth_provider.dart';

final userProvider = Provider<User?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.value;
});
