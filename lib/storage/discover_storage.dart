import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:studently/logger.dart';
import 'package:studently/models/user.dart';

class DiscoverStorage {
  final Box _box;

  static const _discoverUsersKey = 'discover_users';
  static const _discoverLastFetchKey = 'discover_last_fetch';
  static const _pendingRequestsKey = 'discover_pending_requests';
  static const _pendingLastFetchKey = 'discover_pending_last_fetch';
  static const _swipedLeftKey = 'discover_swiped_left_ids';

  DiscoverStorage(this._box);

  List<User> getCachedDiscoverUsers() {
    final String? cachedJson = _box.get(_discoverUsersKey);
    if (cachedJson == null) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(cachedJson);
      return decoded.map((e) => User.fromJson(e)).toList();
    } catch (e) {
      logger.e('[DiscoverStorage] Error decoding cached discover users: $e');
      return [];
    }
  }

  void saveDiscoverUsers(List<User> users) {
    try {
      final json = jsonEncode(users.take(60).map((u) => u.toJson()).toList());
      _box.put(_discoverUsersKey, json);
    } catch (e) {
      logger.e('[DiscoverStorage] Error saving discover users: $e');
    }
  }

  int? getDiscoverLastFetchTime() {
    return _box.get(_discoverLastFetchKey) as int?;
  }

  void setDiscoverLastFetchTime(int timeMs) {
    _box.put(_discoverLastFetchKey, timeMs);
  }

  List<User> getCachedPendingRequests() {
    final String? cachedJson = _box.get(_pendingRequestsKey);
    if (cachedJson == null) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(cachedJson);
      return decoded.map((e) => User.fromJson(e)).toList();
    } catch (e) {
      logger.e('[DiscoverStorage] Error decoding cached requests: $e');
      return [];
    }
  }

  void savePendingRequests(List<User> requests) {
    try {
      final json = jsonEncode(requests.map((u) => u.toJson()).toList());
      _box.put(_pendingRequestsKey, json);
    } catch (e) {
      logger.e('[DiscoverStorage] Error saving pending requests: $e');
    }
  }

  int? getPendingLastFetchTime() {
    return _box.get(_pendingLastFetchKey) as int?;
  }

  void setPendingLastFetchTime(int timeMs) {
    _box.put(_pendingLastFetchKey, timeMs);
  }

  Set<String> getSwipedLeftIds() {
    final List<dynamic>? cachedIds = _box.get(_swipedLeftKey);
    if (cachedIds == null) {
      return <String>{};
    }
    return cachedIds.map((e) => e.toString()).toSet();
  }

  void saveSwipedLeftIds(Set<String> ids) {
    _box.put(_swipedLeftKey, ids.toList());
  }

  void addSwipedLeftId(String id) {
    final ids = getSwipedLeftIds();
    if (ids.add(id)) {
      saveSwipedLeftIds(ids);
    }
  }

  void clearSwipedLeftIds() {
    _box.delete(_swipedLeftKey);
  }

  Future<void> clearStorage() async {
    await _box.deleteAll([
      _discoverUsersKey,
      _discoverLastFetchKey,
      _pendingRequestsKey,
      _pendingLastFetchKey,
      _swipedLeftKey,
    ]);
  }
}
