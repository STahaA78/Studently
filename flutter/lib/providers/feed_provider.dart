import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/post.dart';
import '../repositories/post.dart';
import 'package:studently/services/firebase_auth.dart';

import '../providers/auth_provider.dart';

class FeedState {
  final List<Post> posts;
  final bool isLoading;
  final bool isFetchingMore;
  final bool hasMore;
  final String? error;

  FeedState({
    required this.posts,
    this.isLoading = false,
    this.isFetchingMore = false,
    this.hasMore = true,
    this.error,
  });

  FeedState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isFetchingMore,
    bool? hasMore,
    String? error,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class FeedNotifier extends Notifier<FeedState> {
  int _skip = 0;
  final int _limit = 10;
  static const String _boxName = 'feed_box';

  @override
  FeedState build() {
    // 1. Initial State
    final initialState = FeedState(posts: []);
    
    // 2. Load from Hive ASAP
    _loadFromHive();
    
    return initialState;
  }

  PostRepository get repository => PostRepository();

  Future<void> editPost(String postId, String content) async {
    final originalPosts = [...state.posts];
    final postIndex = state.posts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final post = state.posts[postIndex];
    final updatedPost = Post(
      id: post.id,
      authorId: post.authorId,
      authorName: post.authorName,
      authorPic: post.authorPic,
      content: content,
      mediaUrls: post.mediaUrls,
      likes: post.likes,
      comments: post.comments,
      timestamp: post.timestamp,
    );

    final newPosts = [...state.posts];
    newPosts[postIndex] = updatedPost;
    state = state.copyWith(posts: newPosts);

    try {
      await repository.editPost(postId, content);
      _saveToHive(state.posts);
    } catch (e) {
      state = state.copyWith(posts: originalPosts);
    }
  }

  Future<void> _loadFromHive() async {
    try {
      final box = await Hive.openBox<Post>(_boxName);
      if (box.isNotEmpty) {
        final cachedPosts = box.values.toList();
        // Sort by timestamp descending
        cachedPosts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        state = state.copyWith(posts: cachedPosts);
      }
      
      // After loading cache, trigger a background refresh
      refreshFeed();
    } catch (e) {
      // If hive fails, just refresh from API
      refreshFeed();
    }
  }

  Future<void> _saveToHive(List<Post> posts) async {
    try {
      final box = await Hive.openBox<Post>(_boxName);
      await box.clear();
      await box.addAll(posts);
    } catch (_) {}
  }

  Future<void> refreshFeed() async {
    if (state.isLoading) return;
    
    state = state.copyWith(isLoading: true, error: null);
    _skip = 0;
    try {
      final posts = await repository.getFeed(skip: _skip, limit: _limit);
      
      // Patch author info for current user to handle backend denormalization lag
      final currentUser = ref.read(authProvider).value;
      final patchedPosts = posts.map((post) {
        if (currentUser != null && (post.authorId == currentUser.id || post.authorId.contains(currentUser.id))) {
          return Post(
            id: post.id,
            authorId: post.authorId,
            authorName: currentUser.name, // Latest name from local profile
            authorPic: currentUser.profilePhotoUrl, // Latest photo from local profile
            content: post.content,
            mediaUrls: post.mediaUrls,
            likes: post.likes,
            comments: post.comments,
            timestamp: post.timestamp,
          );
        }
        return post;
      }).toList();

      state = state.copyWith(
        posts: patchedPosts,
        isLoading: false,
        hasMore: posts.length >= _limit,
      );
      
      // Sync with Disk
      _saveToHive(patchedPosts);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMorePosts() async {
    if (state.isFetchingMore || !state.hasMore) return;

    state = state.copyWith(isFetchingMore: true);
    _skip += _limit;

    try {
      final List<Post> newPosts = await repository.getFeed(skip: _skip, limit: _limit);
      
      // Patch author info for current user
      final currentUser = ref.read(authProvider).value;
      final patchedNewPosts = newPosts.map((post) {
        if (currentUser != null && (post.authorId == currentUser.id || post.authorId.contains(currentUser.id))) {
          return Post(
            id: post.id,
            authorId: post.authorId,
            authorName: currentUser.name,
            authorPic: currentUser.profilePhotoUrl,
            content: post.content,
            mediaUrls: post.mediaUrls,
            likes: post.likes,
            comments: post.comments,
            timestamp: post.timestamp,
          );
        }
        return post;
      }).toList();

      final List<Post> allPosts = [...state.posts, ...patchedNewPosts];
      state = state.copyWith(
        posts: allPosts,
        isFetchingMore: false,
        hasMore: newPosts.length >= _limit,
      );
      
      if (_skip == 0) _saveToHive(allPosts);
    } catch (e) {
      state = state.copyWith(isFetchingMore: false, error: e.toString());
    }
  }

  Future<void> toggleLike(String postId) async {
    final currentUser = authService.value.firebaseAuth.currentUser?.uid;
    if (currentUser == null) return;

    final originalPosts = [...state.posts];
    final postIndex = state.posts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final post = state.posts[postIndex];
    final List<String> updatedLikes = [...post.likes];
    
    if (updatedLikes.contains(currentUser)) {
      updatedLikes.remove(currentUser);
    } else {
      updatedLikes.add(currentUser);
    }

    final updatedPost = Post(
      id: post.id,
      authorId: post.authorId,
      authorName: post.authorName,
      authorPic: post.authorPic,
      content: post.content,
      mediaUrls: post.mediaUrls,
      likes: updatedLikes,
      comments: post.comments,
      timestamp: post.timestamp,
    );

    final newPosts = [...state.posts];
    newPosts[postIndex] = updatedPost;
    state = state.copyWith(posts: newPosts);

    try {
      await repository.likePost(postId);
      _saveToHive(state.posts); // Update disk
    } catch (e) {
      state = state.copyWith(posts: originalPosts);
    }
  }

  Future<void> deletePost(String postId) async {
    final originalPosts = [...state.posts];
    state = state.copyWith(posts: state.posts.where((p) => p.id != postId).toList());

    try {
      await repository.deletePost(postId);
      _saveToHive(state.posts); // Update disk
    } catch (e) {
      state = state.copyWith(posts: originalPosts);
    }
  }

  void updateAuthorName(String userId, String newName) {
    print("DEBUG: updateAuthorName triggered for $userId -> $newName");
    final updatedPosts = state.posts.map((post) {
      // Use more flexible matching in case of ID format differences
      if (post.authorId == userId || post.authorId.contains(userId) || userId.contains(post.authorId)) {
        print("DEBUG: Matching post found! Updating ${post.authorName} to $newName");
        return Post(
          id: post.id,
          authorId: post.authorId,
          authorName: newName,
          authorPic: post.authorPic,
          content: post.content,
          mediaUrls: post.mediaUrls,
          likes: post.likes,
          comments: post.comments,
          timestamp: post.timestamp,
        );
      }
      return post;
    }).toList();
    state = state.copyWith(posts: updatedPosts);
    _saveToHive(state.posts);
  }
}

final feedProvider = NotifierProvider<FeedNotifier, FeedState>(() {
  return FeedNotifier();
});
