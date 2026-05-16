import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/app_style.dart';
import 'package:studently/models/post.dart';
import 'package:studently/providers/auth_provider.dart';
import 'package:studently/providers/feed_provider.dart';
import 'package:studently/screens/profile_main.dart';
import 'package:studently/services/firebase_auth.dart';

Future<void> showPostCommentsSheet(
  BuildContext context,
  Post post,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PostCommentsSheet(postData: post),
  );
}

class PostCommentsSheet extends ConsumerStatefulWidget {
  final Post postData;

  const PostCommentsSheet({super.key, required this.postData});

  @override
  ConsumerState<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends ConsumerState<PostCommentsSheet> {
  late Post post;
  bool isSending = false;
  bool _isRefreshing = false;
  final TextEditingController commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    post = widget.postData;
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  void _syncPostGlobally() {
    ref.read(feedProvider.notifier).updatePostLocally(post);
    ref.read(profileFeedProvider(post.authorId).notifier).syncPostUpdate(post);
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

  Future<void> _refreshPost() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final repository = ref.read(postRepositoryProvider);
      final freshPost = await repository.getPostById(post.id);
      setState(() => post = freshPost);
      _syncPostGlobally();
    } catch (e) {
      debugPrint('Refresh comments failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> submitComment() async {
    final text = commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => isSending = true);

    try {
      final repository = ref.read(postRepositoryProvider);
      await repository.addComment(post.id, text);

      setState(() {
        final uid = authService.value.currentUser?.uid ?? '';
        final currentUser = ref.read(authProvider).value;

        final newComment = Comment(
          userId: uid,
          username: 'You',
          picture: currentUser?.picture,
          text: text,
          timestamp: DateTime.now().toUtc(),
        );

        post = post.copyWith(
          comments: List<Comment>.from(post.comments)..add(newComment),
        );
        commentController.clear();
      });

      _syncPostGlobally();
    } catch (e) {
      debugPrint('Comment error: $e');
    } finally {
      if (mounted) {
        setState(() => isSending = false);
      }
    }
  }

  Future<void> deleteComment(Comment comment) async {
    final index = post.comments.indexOf(comment);
    if (index < 0) return;

    try {
      final confirmed = await _showDeleteConfirmation(
        title: 'Delete Comment',
        message: 'Are you sure you want to delete this comment?',
      );

      if (confirmed != true) return;

      final repository = ref.read(postRepositoryProvider);
      await repository.deleteComment(post.id, index);

      setState(() {
        post = post.copyWith(
          comments: List<Comment>.from(post.comments)..removeAt(index),
        );
      });

      _syncPostGlobally();
    } catch (e) {
      debugPrint('Delete comment error: $e');
    }
  }

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

  String formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Center(
                        child: Text(
                          'Comments',
                          style: TextStyle(
                            fontSize: AppStyle.appBarTitleSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: _isRefreshing
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh, color: Colors.black),
                              onPressed: _isRefreshing ? null : _refreshPost,
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.black),
                              onPressed: () => Navigator.pop(context, post),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [

                    if (post.comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No comments yet. Be the first to comment.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ...post.comments.map(_buildCommentTile),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomInset),
                child: SafeArea(
                  top: false,
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
                            hintText: 'Add a comment...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: isSending
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color: AppStyle.primaryBlue,
                              ),
                        onPressed: isSending ? null : submitComment,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentTile(Comment comment) {
    final currentUid = authService.value.currentUser?.uid;
    final isOwner = comment.userId == currentUid;
    final displayName = isOwner
        ? 'You'
        : (comment.username.trim().isNotEmpty &&
                comment.username.toLowerCase() != 'unknown'
            ? comment.username
            : 'User');
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
                                message:
                                    'Are you sure you want to delete this comment?',
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
                Text(
                  comment.text,
                  softWrap: true,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}