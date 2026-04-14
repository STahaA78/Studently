import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:studently/models/post.dart';
import 'package:studently/repositories/post.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/logger.dart';
import 'package:studently/providers/auth_provider.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository();
});

class FeedNotifier extends AsyncNotifier<List<Post>> {
  final _feedBox = Hive.box('feedBox');
  static const _feedKey = 'cached_community_feed';
  static const _lastFetchKey = 'last_feed_fetch_time';
  
  int _skip = 0;
  final int _limit = 20; 
  bool _hasMore = true;
  bool _isFetchingMore = false; 

  @override
  Future<List<Post>> build() async {
    ref.keepAlive();
    
    // Watch authProvider to trigger a rebuild (and thus name hydration) when user profile changes
    final authState = ref.watch(authProvider);
    final currentUser = authState.value;

    final String? cachedJson = _feedBox.get(_feedKey);
    List<Post> cachedPosts = [];
    if (cachedJson != null) {
      final List<dynamic> decoded = jsonDecode(cachedJson);
      cachedPosts = decoded.map((e) => Post.fromJson(e)).toList();
    }

    // Hydrate names for current user's posts
    if (currentUser != null) {
      cachedPosts = _hydrateNames(cachedPosts, currentUser.id, currentUser.name);
    }

    final lastFetch = _feedBox.get(_lastFetchKey) as int?;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (cachedPosts.isEmpty || lastFetch == null || (now - lastFetch) > 300000) {
      _fetchFreshFeed();
    }

    return cachedPosts;
  }

  List<Post> _hydrateNames(List<Post> posts, String currentUserId, String currentUserName) {
    return posts.map((post) {
      if (post.authorId == currentUserId && post.authorName != currentUserName) {
        return post.copyWith(authorName: currentUserName);
      }
      return post;
    }).toList();
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
      
      // Hydrate before setting state
      final currentUser = ref.read(authProvider).value;
      final hydratedPosts = currentUser != null 
          ? _hydrateNames(freshPosts, currentUser.id, currentUser.name)
          : freshPosts;

      state = AsyncValue.data(hydratedPosts);
      _saveToCache(hydratedPosts);
      _feedBox.put(_lastFetchKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e, stack) {
      logger.e("Feed fetch failed", error: e, stackTrace: stack);
    } finally {
      _isFetchingMore = false;
    }
  }

  void _saveToCache(List<Post> posts) {
    final json = jsonEncode(posts.take(40).map((e) => e.toJson()).toList());
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
      final existingIds = currentPosts.map((p) => p.id).toSet();
      var filteredNext = nextPosts.where((p) => !existingIds.contains(p.id)).toList();
      
      if (filteredNext.isNotEmpty) {
        final currentUser = ref.read(authProvider).value;
        if (currentUser != null) {
          filteredNext = _hydrateNames(filteredNext, currentUser.id, currentUser.name);
        }
        state = AsyncValue.data([...currentPosts, ...filteredNext]);
        _saveToCache(state.value!);
      } else if (nextPosts.length < _limit) {
        _hasMore = false;
      }
    } finally {
      _isFetchingMore = false;
    }
  }

  void toggleLike(String postId) async {
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

    state = AsyncValue.data(updatedList);

    try {
      final repo = ref.read(postRepositoryProvider);
      await repo.likePost(postId);
      _saveToCache(updatedList);
    } catch (e) {
      state = AsyncValue.data(currentPosts); 
    }
  }

  void deletePost(String postId) async {
    final currentPosts = state.value;
    if (currentPosts == null) return;

    final postIndex = currentPosts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final originalPosts = [...currentPosts];
    final updatedList = [...currentPosts]..removeAt(postIndex);

    state = AsyncValue.data(updatedList);

    try {
      final repo = ref.read(postRepositoryProvider);
      await repo.deletePost(postId);
      _saveToCache(updatedList);
    } catch (e) {
      state = AsyncValue.data(originalPosts); 
    }
  }

  void updatePostLocally(Post updatedPost) {
    final currentPosts = state.value;
    if (currentPosts == null) return;
    final index = currentPosts.indexWhere((p) => p.id == updatedPost.id);
    if (index == -1) return;
    final newList = [...currentPosts];
    newList[index] = updatedPost;
    state = AsyncValue.data(newList);
    _saveToCache(newList);
  }

  void updateAuthorNameLocally(String userId, String newName) {
    final currentPosts = state.value;
    if (currentPosts == null) return;
    final newList = currentPosts.map((post) {
      return post.authorId == userId ? post.copyWith(authorName: newName) : post;
    }).toList();
    state = AsyncValue.data(newList);
    _saveToCache(newList);
  }
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, List<Post>>(() => FeedNotifier());

class ProfileFeedNotifier extends AsyncNotifier<List<Post>> {
  final String userId;
  ProfileFeedNotifier(this.userId);

  final _profileBox = Hive.box('profileFeedBox');
  int _skip = 0;
  final int _limit = 50; 
  bool _hasMore = true;

  @override
  Future<List<Post>> build() async {
    ref.keepAlive();
    final authState = ref.watch(authProvider);
    final currentUser = authState.value;

    final String? cachedJson = _profileBox.get('profile_$userId');
    List<Post> cachedPosts = [];
    if (cachedJson != null) {
      final List<dynamic> decoded = jsonDecode(cachedJson);
      cachedPosts = decoded.map((e) => Post.fromJson(e)).toList();
    }

    if (currentUser != null && userId == currentUser.id) {
      cachedPosts = cachedPosts.map((p) => p.copyWith(authorName: currentUser.name)).toList();
    }

    _fetchProfilePosts(reset: true);
    return cachedPosts;
  }

  Future<void> _fetchProfilePosts({bool reset = false}) async {
    if (reset) {
      _skip = 0;
      _hasMore = true;
    }
    
    try {
      final repo = ref.read(postRepositoryProvider);
      List<Post> allUserPosts = [];
      int currentSkip = reset ? 0 : _skip;
      bool foundMorePosts = true;

      // Keep fetching until we've gone through the entire feed or found enough posts
      while (foundMorePosts && currentSkip < 1000) { // Safety limit: 1000 posts
        final batch = await repo.getFeed(skip: currentSkip, limit: _limit);
        
        if (batch.isEmpty) {
          foundMorePosts = false;
          break;
        }

        final userPostsInBatch = batch.where((p) => p.authorId == userId).toList();
        allUserPosts.addAll(userPostsInBatch);

        // If we got fewer posts than limit, we've reached the end
        if (batch.length < _limit) {
          foundMorePosts = false;
          _hasMore = false;
        }

        currentSkip += _limit;
      }

      final currentUser = ref.read(authProvider).value;
      final hydrated = (currentUser != null && userId == currentUser.id)
          ? allUserPosts.map((p) => p.copyWith(authorName: currentUser.name)).toList()
          : allUserPosts;

      state = AsyncValue.data(hydrated);
      _profileBox.put('profile_$userId', jsonEncode(hydrated.map((e) => e.toJson()).toList()));
      _skip = currentSkip;

    } catch (e) {
      logger.e("Profile fetch failed", error: e);
    }
  }

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

  void updateAuthorNameLocally(String newName) {
    final currentPosts = state.value;
    if (currentPosts == null) return;
    final newList = currentPosts.map((post) => post.copyWith(authorName: newName)).toList();
    state = AsyncValue.data(newList);
    _profileBox.put('profile_$userId', jsonEncode(newList.map((e) => e.toJson()).toList()));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    await _fetchProfilePosts(reset: true);
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    await _fetchProfilePosts(reset: false);
  }
}

final profileFeedProvider = AsyncNotifierProvider.family<ProfileFeedNotifier, List<Post>, String>((userId) {
  return ProfileFeedNotifier(userId);
});

// Scroll Notifiers
class FeedScrollNotifier extends Notifier<double> {
  @override
  double build() => 0.0;
  void set(double value) => state = value;
}
final feedScrollProvider = NotifierProvider<FeedScrollNotifier, double>(() => FeedScrollNotifier());

class ProfileScrollNotifier extends Notifier<double> {
  final String userId;
  ProfileScrollNotifier(this.userId);
  @override
  double build() => 0.0;
  void set(double value) => state = value;
}
final profileScrollProvider = NotifierProvider.family<ProfileScrollNotifier, double, String>((userId) {
  return ProfileScrollNotifier(userId);
});
