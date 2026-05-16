import 'package:studently/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/models/post.dart';
import 'package:studently/screens/profile_main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/utils/web_utils.dart' as web_utils;
import 'package:studently/providers/auth_provider.dart';
import 'package:studently/providers/feed_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PostDetailsPage extends ConsumerStatefulWidget {
  final Post postData;

  const PostDetailsPage({super.key, required this.postData});

  @override
  ConsumerState<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends ConsumerState<PostDetailsPage> {
  late Post post;
  String? currentUserId;
  bool _isRefreshing = false;

  final TextEditingController commentController = TextEditingController();

  bool isSending = false;

  @override
  void initState() {
    super.initState();
    post = widget.postData;
    currentUserId = authService.value.firebaseAuth.currentUser?.uid;
  }

  Future<bool?> _showDeleteConfirmation({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  /// ---------------- COMMENT SUBMIT ----------------
  Future<void> submitComment() async {
    final text = commentController.text.trim();

    if (text.isEmpty) return;

    setState(() => isSending = true);

    try {
      final repository = ref.read(postRepositoryProvider);
      await repository.addComment(post.id, text);

      setState(() {
        final uid = authService.value.currentUser?.uid ?? "";
        final currentUser = ref.read(authProvider).value;
        final currentUserPicture = currentUser?.picture;

        final newComment = Comment(
          userId: uid,
          username: "You",
          picture: currentUserPicture,
          text: text,
          timestamp: DateTime.now().toUtc(),
        );

        final updatedComments = List<Comment>.from(post.comments)
          ..add(newComment);
        post = post.copyWith(comments: updatedComments);

        commentController.clear();
      });

      _syncPostGlobally();
    } catch (e) {
      debugPrint("Comment error: $e");
    }

    setState(() => isSending = false);
  }

  /// ---------------- DELETE COMMENT ----------------
  Future<void> deleteComment(Comment comment) async {
    final index = post.comments.indexOf(comment);

    try {
      final repository = ref.read(postRepositoryProvider);
      await repository.deleteComment(post.id, index);

      setState(() {
        final updatedComments = List<Comment>.from(post.comments)
          ..removeAt(index);
        post = post.copyWith(comments: updatedComments);
      });

      _syncPostGlobally();
    } catch (e) {
      debugPrint("Delete comment error: $e");
    }
  }

  void _syncPostGlobally() {
    ref.read(feedProvider.notifier).updatePostLocally(post);
    ref.read(profileFeedProvider(post.authorId).notifier).syncPostUpdate(post);
  }
  /// ---------------- LIKE ----------------
  void toggleLike() async {
    if (currentUserId == null) return;

    final isLiked = post.likes.contains(currentUserId);
    final newLikes = List<String>.from(post.likes);
    if (isLiked) {
      newLikes.remove(currentUserId);
    } else {
      newLikes.add(currentUserId!);
    }

    setState(() {
      post = post.copyWith(likes: newLikes);
    });

    _syncPostGlobally();

    try {
      final repository = ref.read(postRepositoryProvider);
      await repository.likePost(post.id);
    } catch (e) {
      debugPrint("Like error: $e");
      // Rollback not implemented here for simplicity as we already have optimistic updates in providers
    }
  }

  /// ---------------- TIME FORMAT ----------------
  String formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  /// ---------------- PROFILE NAVIGATION ----------------
  void openProfile(String userId) {
    final currentUid = authService.value.currentUser?.uid;

    if (userId == currentUid) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfilePage(userId: userId)),
      );
    }
  }

  /// ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: Center(
          child: const Text(
            "Post",
            style: TextStyle(
              color: Colors.black,
              fontSize: AppStyle.appBarTitleSize,
              fontWeight: FontWeight.w600),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context, post),
        ),
        actions: [
          if (kIsWeb && !web_utils.isStandalonePwa())
            IconButton(
              icon: _isRefreshing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, color: Colors.black),
              onPressed: _isRefreshing
                  ? null
                  : () async {
                      setState(() => _isRefreshing = true);
                      try {
                        final repository = ref.read(postRepositoryProvider);
                        final fresh = await repository.getPostById(post.id);
                        setState(() => post = fresh);
                        _syncPostGlobally();
                      } catch (e) {
                        debugPrint('Refresh post error: $e');
                      }
                      setState(() => _isRefreshing = false);
                    },
            ),
          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildPostCard(),
                const SizedBox(height: 16),
                ...post.comments.map(_buildCommentTile),
              ],
            ),
          ),

          /// COMMENT INPUT
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: "Add a comment...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        // Use neutral border on focus to avoid blue accent while typing
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),

                  IconButton(
                    icon: isSending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: AppStyle.primaryBlue),
                    onPressed: isSending ? null : submitComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ---------------- POST CARD ----------------
  Widget _buildPostCard() {
    final String? pic = post.authorPic;
    final bool hasPic = pic != null && pic.isNotEmpty;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: Colors.white),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// AUTHOR (CLICKABLE)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => openProfile(post.authorId),

              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: hasPic ? CachedNetworkImageProvider(pic) : null,
                    child: Text(
                      post.authorName.isNotEmpty ? post.authorName[0] : "?",
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                        fontSize: 14
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),

                      Text(
                        formatTime(post.timestamp),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          /// POST CONTENT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 19),
            child: Text(post.content, style: const TextStyle(fontSize: 15)),
          ),

          const SizedBox(height: 8),

          if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: AspectRatio(
                aspectRatio: post.mediaAspectRatio ?? 4 / 5,
                child: Image.network(
                  post.mediaUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey[600],
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Image failed to load',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            icon: Icon(
                              Icons.refresh,
                              color: Colors.grey[600],
                            ),
                            onPressed: () {
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          /// LIKE + COMMENT
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 19),
            child: Row(
              children: [
                GestureDetector(
                  onTap: toggleLike,
                  child: SvgPicture.asset(
                    post.likes.contains(currentUserId)
                        ? 'assets/images/like-active.svg'
                        : 'assets/images/like-inactive.svg',
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(
                      post.likes.contains(currentUserId) ? Colors.red : Colors.black,
                      BlendMode.srcIn,
                    ),
                  ),
                ),

                const SizedBox(width: 6),
                Text("${post.likes.length}"),

                const SizedBox(width: 12),

                SvgPicture.asset(
                  'assets/images/comment.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                    Colors.black,
                    BlendMode.srcIn,
                  ),
                ),

                const SizedBox(width: 6),
                Text("${post.comments.length}"),
              ],
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// ---------------- COMMENT TILE ----------------
  Widget _buildCommentTile(Comment comment) {
    final currentUid = authService.value.currentUser?.uid;
    final bool isOwner = comment.userId == currentUid;
    final displayName = isOwner
        ? "You"
        : (comment.username.trim().isNotEmpty &&
                  comment.username.toLowerCase() != "Unknown"
              ? comment.username
              : "User");
    final hasPicture = comment.picture != null && comment.picture!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => openProfile(comment.userId),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade300,
              backgroundImage:
                  hasPicture ? CachedNetworkImageProvider(comment.picture!) : null,
              child: hasPicture
                  ? null
                  : Text(
                      displayName.isNotEmpty ? displayName[0] : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => openProfile(comment.userId),
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    if (isOwner)
                      SizedBox(
                        height: 20,
                        width: 28,
                        child: PopupMenuButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.more_vert, size: 20),
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                          onSelected: (value) async {
                            if (value == 'delete') {
                              final confirm = await _showDeleteConfirmation(
                                title: 'Delete Comment',
                                message: 'Are you sure you want to delete this comment?',
                              );
                              if (confirm == true) {
                                await deleteComment(comment);
                              }
                            }
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  formatTime(comment.timestamp),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    comment.text,
                    softWrap: true,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
                
              ],
            ),
          ),
        ],
      ),
    );
  }
}
