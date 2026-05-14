import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:studently/models/post.dart';
import 'package:studently/logger.dart';

class FeedStorage {
  final Box _feedBox;
  final Box _profileFeedBox;

  static const _feedKey = 'cached_community_feed';
  static const _lastFetchKey = 'last_feed_fetch_time';

  String _profileKey(String userId) => 'profile_$userId';

  FeedStorage(this._feedBox, this._profileFeedBox);

  // --- Community Feed ---
  List<Post> getCachedFeed() {
    final String? cachedJson = _feedBox.get(_feedKey);
    if (cachedJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        return decoded.map((e) => Post.fromJson(e)).toList();
      } catch (e) {
        logger.e('[FeedStorage] Error decoding cached feed: $e');
      }
    }
    return [];
  }

  void saveFeed(List<Post> posts) {
    final json = jsonEncode(posts.take(40).map((e) => e.toJson()).toList());
    _feedBox.put(_feedKey, json);
  }

  int? getLastFetchTime() {
    return _feedBox.get(_lastFetchKey) as int?;
  }

  void setLastFetchTime(int timeMs) {
    _feedBox.put(_lastFetchKey, timeMs);
  }

  // --- Profile Feed ---
  List<Post> getCachedProfileFeed(String userId) {
    final String? cachedJson = _profileFeedBox.get(_profileKey(userId));
    if (cachedJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        return decoded.map((e) => Post.fromJson(e)).toList();
      } catch (e) {
        logger.e('[FeedStorage] Error decoding profile feed: $e');
      }
    }
    return [];
  }

  void saveProfileFeed(String userId, List<Post> posts) {
    _profileFeedBox.put(
      _profileKey(userId),
      jsonEncode(posts.map((e) => e.toJson()).toList()),
    );
  }
}
