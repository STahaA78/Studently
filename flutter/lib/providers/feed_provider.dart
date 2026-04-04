import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:studently/models/post.dart';
import 'package:studently/repositories/post.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/logger.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository();
});

class FeedNotifier extends AsyncNotifier<List<Post>> {
  final _feedBox = Hive.box('feedBox');
  static const _feedKey = 'cached_community_feed';
  static const _lastFetchKey = 'last_feed_fetch_time';
  
  int _skip = 0;
  final int _limit = 10;
  bool _hasMore = true;
  bool _isFetchingMore = false; // Prevent duplicate parallel fetches

  @override
  Future<List<Post>> build() async {
    logger.i("[$runtimeType] build() started - Checking local cache");
    
    // 1. Load from Hive for instant UI
    final String? cachedJson = _feedBox.get(_feedKey);
    List<Post> cachedPosts = [];
    if (cachedJson != null) {
      final List<dynamic> decoded = jsonDecode(cachedJson);
      cachedPosts = decoded.map((e) => Post.fromJson(e)).toList();
      logger.d("[$runtimeType] Loaded ${cachedPosts.length} posts from cache");
    }

    // 2. Check if we should fetch fresh data (Eventual Consistency / Lifecycle Refresh)
    final lastFetch = _feedBox.get(_lastFetchKey) as int?;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (cachedPosts.isEmpty || lastFetch == null || (now - lastFetch) > 300000) { // 5 minutes stale
      _fetchFreshFeed();
    }

    return cachedPosts;
  }

  Future<void> _fetchFreshFeed() async {
    if (_isFetchingMore) return;
    _isFetchingMore = true;
    try {
      _skip = 0;
      final repo = ref.read(postRepositoryProvider);
      final freshPosts = await repo.getFeed(skip: _skip, limit: _limit);
      
      _skip = freshPosts.length;
      _hasMore = freshPosts.length >= _limit;
      
      state = AsyncValue.data(freshPosts);
      _saveToCache(freshPosts);
      _feedBox.put(_lastFetchKey, DateTime.now().millisecondsSinceEpoch);
      logger.i("[$runtimeType] Fresh feed fetched and cached");
    } catch (e, stack) {
      logger.e("[$runtimeType] Failed to fetch fresh feed", error: e, stackTrace: stack);
    } finally {
      _isFetchingMore = false;
    }
  }

  void _saveToCache(List<Post> posts) {
    final json = jsonEncode(posts.map((e) => e.toJson()).toList());
    _feedBox.put(_feedKey, json);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    await _fetchFreshFeed();
  }

  Future<void> loadMore() async {
    if (_isFetchingMore || !_hasMore) return;
    _isFetchingMore = true;
    
    try {
      final repo = ref.read(postRepositoryProvider);
      final nextPosts = await repo.getFeed(skip: _skip, limit: _limit);
      
      if (nextPosts.isEmpty) {
        _hasMore = false;
        return;
      }

      _skip += nextPosts.length;
      _hasMore = nextPosts.length >= _limit;
      
      final currentPosts = state.value ?? [];
      
      // Filter out potential duplicates if backend order shifted
      final existingIds = currentPosts.map((p) => p.id).toSet();
      final filteredNext = nextPosts.where((p) => !existingIds.contains(p.id)).toList();
      
      if (filteredNext.isNotEmpty) {
        state = AsyncValue.data([...currentPosts, ...filteredNext]);
        
        // Update cache with first 20 posts for quick cold start
        final updatedList = state.value!;
        _saveToCache(updatedList.take(20).toList());
      } else if (nextPosts.length < _limit) {
        _hasMore = false;
      }
      
    } catch (e) {
      logger.e("[$runtimeType] Pagination failed", error: e);
    } finally {
      _isFetchingMore = false;
    }
  }

  // Optimistic Like
  Future<void> toggleLike(String postId) async {
    final currentPosts = state.value;
    if (currentPosts == null) return;

    final userId = authService.value.currentUser?.uid;
    if (userId == null) return;

    final postIndex = currentPosts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final post = currentPosts[postIndex];
    final isLiked = post.likes.contains(userId);
    
    final newLikes = List<String>.from(post.likes);
    if (isLiked) {
      newLikes.remove(userId);
    } else {
      newLikes.add(userId);
    }

    final updatedPost = post.copyWith(likes: newLikes);
    final updatedList = [...currentPosts];
    updatedList[postIndex] = updatedPost;

    // Optimistic UI Update
    state = AsyncValue.data(updatedList);

    try {
      final repo = ref.read(postRepositoryProvider);
      await repo.likePost(postId);
      _saveToCache(updatedList.take(20).toList());
    } catch (e) {
      logger.e("[$runtimeType] Like failed, rolling back", error: e);
      state = AsyncValue.data(currentPosts); // Rollback
    }
  }

  // Optimistic Delete
  Future<void> deletePost(String postId) async {
    final currentPosts = state.value;
    if (currentPosts == null) return;

    final postIndex = currentPosts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final originalPosts = [...currentPosts];
    final updatedList = [...currentPosts]..removeAt(postIndex);

    // Optimistic UI Update
    state = AsyncValue.data(updatedList);

    try {
      final repo = ref.read(postRepositoryProvider);
      await repo.deletePost(postId);
      _saveToCache(updatedList.take(20).toList());
    } catch (e) {
      logger.e("[$runtimeType] Delete failed, rolling back", error: e);
      state = AsyncValue.data(originalPosts); // Rollback
    }
  }

  // Update a single post (e.g. after edit or comment)
  void updatePostLocally(Post updatedPost) {
    final currentPosts = state.value;
    if (currentPosts == null) return;

    final postIndex = currentPosts.indexWhere((p) => p.id == updatedPost.id);
    if (postIndex == -1) return;

    final updatedList = [...currentPosts];
    updatedList[postIndex] = updatedPost;
    state = AsyncValue.data(updatedList);
    _saveToCache(updatedList.take(20).toList());
  }
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, List<Post>>(() {
  return FeedNotifier();
});

// Profile Feed Provider (Parameterized for specific users)
class ProfileFeedNotifier extends AsyncNotifier<List<Post>> {
  final String userId;
  ProfileFeedNotifier(this.userId);

  final _profileBox = Hive.box('profileFeedBox');

  @override
  Future<List<Post>> build() async {
    // Load from Hive
    final String? cachedJson = _profileBox.get('profile_$userId');
    List<Post> cachedPosts = [];
    if (cachedJson != null) {
      final List<dynamic> decoded = jsonDecode(cachedJson);
      cachedPosts = decoded.map((e) => Post.fromJson(e)).toList();
    }

    // Always fetch fresh for profile to ensure consistency
    _fetchProfilePosts();

    return cachedPosts;
  }

  Future<void> _fetchProfilePosts() async {
    try {
      final repo = ref.read(postRepositoryProvider);
      // Fixed: Changed limit from 100 to 50 to avoid 422 error from backend
      final allPosts = await repo.getFeed(skip: 0, limit: 50); 
      final userPosts = allPosts.where((p) => p.authorId == userId).toList();
      
      state = AsyncValue.data(userPosts);
      _profileBox.put('profile_$userId', jsonEncode(userPosts.map((e) => e.toJson()).toList()));
    } catch (e) {
      logger.e("[$runtimeType] Profile fetch failed", error: e);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    await _fetchProfilePosts();
  }

  // Reuse logic for toggleLike and delete locally to sync across UI
  void syncPostUpdate(Post updatedPost) {
    final currentPosts = state.value;
    if (currentPosts == null) return;

    final index = currentPosts.indexWhere((p) => p.id == updatedPost.id);
    if (index != -1) {
      final newList = [...currentPosts];
      newList[index] = updatedPost;
      state = AsyncValue.data(newList);
      _profileBox.put('profile_$userId', jsonEncode(newList.map((e) => e.toJson()).toList()));
    }
  }
  
  void removePostLocally(String postId) {
    final currentPosts = state.value;
    if (currentPosts == null) return;
    final newList = currentPosts.where((p) => p.id != postId).toList();
    state = AsyncValue.data(newList);
    _profileBox.put('profile_$userId', jsonEncode(newList.map((e) => e.toJson()).toList()));
  }
}

final profileFeedProvider = AsyncNotifierProvider.family<ProfileFeedNotifier, List<Post>, String>((userId) {
  return ProfileFeedNotifier(userId);
});
