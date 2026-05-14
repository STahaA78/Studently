import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:studently/models/user.dart';
import 'package:studently/logger.dart';

class AuthStorage {
  final Box _box;

  static const _userKey = 'cached_user_profile';
  static const _inSignupKey = 'in_signup_flow';
  static const _friendsKey = 'friends_list';

  AuthStorage(this._box);

  bool getInSignupFlow() {
    return _box.get(_inSignupKey, defaultValue: false) as bool;
  }

  void setInSignupFlow(bool value) {
    if (value) {
      _box.put(_inSignupKey, true);
    } else {
      _box.delete(_inSignupKey);
    }
  }

  void clearInSignupFlow() {
    _box.delete(_inSignupKey);
  }

  User? getCachedUser() {
    final String? localJson = _box.get(_userKey);
    if (localJson != null) {
      try {
        return User.fromJson(jsonDecode(localJson));
      } catch (e) {
        logger.e("[AuthStorage] Error decoding cached user: $e");
      }
    }
    return null;
  }

  void saveUser(User user) {
    _box.put(_userKey, jsonEncode(user.toJson()));
  }

  void clearUser() {
    _box.delete(_userKey);
  }

  List<Map<String, String>> getCachedFriends() {
    final cachedFriends = _box.get(_friendsKey);
    if (cachedFriends != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cachedFriends);
        return decoded.map((e) => Map<String, String>.from(e)).toList();
      } catch (e) {
        logger.e("[AuthStorage] Error decoding friends list: $e");
      }
    }
    return [];
  }

  void saveFriendsList(List<Map<String, String>> friends) {
    _box.put(_friendsKey, jsonEncode(friends));
  }

  void clearFriendsList() {
    _box.delete(_friendsKey);
  }
}
