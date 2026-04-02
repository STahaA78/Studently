import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/post.dart';
import '../repositories/post.dart';
import 'package:studently/services/firebase_auth.dart';

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
      state = state.copyWith(
        posts: posts,
        isLoading: false,
        hasMore: posts.length >= _limit,
      );
      
      // Sync with Disk
      _saveToHive(posts);
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
      final List<Post> allPosts = [...state.posts, ...newPosts];
      state = state.copyWith(
        posts: allPosts,
        isFetchingMore: false,
        hasMore: newPosts.length >= _limit,
      );
      
      // Optionally save first page only to hive to keep it lean
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
    final updatedPosts = state.posts.map((post) {
      if (post.authorId == userId) {
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
