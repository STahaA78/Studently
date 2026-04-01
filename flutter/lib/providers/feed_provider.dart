import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  FeedState build() {
    // We return an initial state. 
    // We start the fetch in a microtask only if our internal skip is 0 (first build).
    if (_skip == 0) {
      Future.microtask(() => refreshFeed());
    }
    return FeedState(posts: []);
  }

  PostRepository get _repository => ref.read(feedRepositoryProvider);

  Future<void> refreshFeed() async {
    state = state.copyWith(isLoading: true, error: null);
    _skip = 0;
    try {
      final posts = await _repository.getFeed(skip: _skip, limit: _limit);
      state = state.copyWith(
        posts: posts,
        isLoading: false,
        hasMore: posts.length >= _limit,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMorePosts() async {
    if (state.isFetchingMore || !state.hasMore) return;

    state = state.copyWith(isFetchingMore: true);
    _skip += _limit;

    try {
      final newPosts = await _repository.getFeed(skip: _skip, limit: _limit);
      state = state.copyWith(
        posts: [...state.posts, ...newPosts],
        isFetchingMore: false,
        hasMore: newPosts.length >= _limit,
      );
    } catch (e) {
      state = state.copyWith(isFetchingMore: false, error: e.toString());
    }
  }

  Future<void> toggleLike(String postId) async {
    final currentUser = authService.value.firebaseAuth.currentUser?.uid;
    if (currentUser == null) return;

    // Optimistic Update
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
      await _repository.likePost(postId);
    } catch (e) {
      // Revert on failure
      state = state.copyWith(posts: originalPosts);
    }
  }

  Future<void> deletePost(String postId) async {
    final originalPosts = [...state.posts];
    state = state.copyWith(posts: state.posts.where((p) => p.id != postId).toList());

    try {
      await _repository.deletePost(postId);
    } catch (e) {
      state = state.copyWith(posts: originalPosts);
    }
  }

  void updatePost(Post updatedPost) {
    final index = state.posts.indexWhere((p) => p.id == updatedPost.id);
    if (index != -1) {
      final newPosts = [...state.posts];
      newPosts[index] = updatedPost;
      state = state.copyWith(posts: newPosts);
    }
  }

  void insertPost(Post newPost) {
    state = state.copyWith(posts: [newPost, ...state.posts]);
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
  }
}

final feedRepositoryProvider = Provider((ref) => PostRepository());

final feedProvider = NotifierProvider<FeedNotifier, FeedState>(() {
  return FeedNotifier();
});
