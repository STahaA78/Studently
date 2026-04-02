import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/utils/constants.dart';

import '../models/post.dart';
import '../providers/feed_provider.dart';
import '../services/api.dart';
import 'direct_messages_page.dart';
import 'post_details_page.dart';
import 'profile_main.dart';

import 'main_screen.dart';

class CommunityFeedPage extends ConsumerStatefulWidget {
  const CommunityFeedPage({super.key});

  @override
  ConsumerState<CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends ConsumerState<CommunityFeedPage> {
  final Color blue = const Color(0xFF1976D2);
  final ApiService api = ApiService();
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    scrollController.addListener(() {
      if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent - 200) {
        ref.read(feedProvider.notifier).loadMorePosts();
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  String formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  Future<void> openPostDetails(Post post) async {
    final updatedPost = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailsPage(
          postData: post,
        ),
      ),
    );

    if (updatedPost != null && updatedPost is Post) {
      ref.read(feedProvider.notifier).updateAuthorName(updatedPost.authorId, updatedPost.authorName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);
    final currentUserId = authService.value.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(feedProvider.notifier).refreshFeed(),
          child: CustomScrollView(
            key: const PageStorageKey('community_feed_scroll'),
            controller: scrollController,
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                floating: true,
                snap: true,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/images/logo.svg',
                      height: AppStyle.logoSize * 0.9,
                    ),
                    Flexible(
                      child: Text(
                        'Studently',
                        style: GoogleFonts.poppins(
                          color: blue,
                          fontSize: AppStyle.titleFontSize * 0.9,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: Colors.black, size: 26),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
                  ),
                  IconButton(
                    icon: const Icon(Icons.mail_outline_rounded, color: Colors.black, size: 26),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DirectMessagesPage())),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              if (feedState.isLoading && feedState.posts.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == feedState.posts.length) {
                        return feedState.isFetchingMore
                            ? const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            : const SizedBox.shrink();
                      }
                      final post = feedState.posts[index];
                      final bool isLiked = post.likes.contains(currentUserId);

                      return _buildPostCard(
                        post: post,
                        index: index,
                        isLiked: isLiked,
                        currentUserId: currentUserId,
                      );
                    },
                    childCount: feedState.posts.length + 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard({
    required Post post,
    required int index,
    required bool isLiked,
    String? currentUserId,
  }) {
    void openProfile() {
      if (post.authorId == currentUserId) {
        // Switch to the Profile Tab instead of pushing a new page
        ref.read(navigationIndexProvider.notifier).setIndex(4);
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(userId: post.authorId)));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: openProfile,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey.shade300,
                        child: Text(post.authorName.isNotEmpty ? post.authorName[0] : "?",
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          Text(formatTime(post.timestamp), style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (post.authorId == currentUserId)
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: "edit", child: Text("Edit")),
                      PopupMenuItem(value: "delete", child: Text("Delete")),
                    ],
                    onSelected: (value) async {
                      if (value == "edit") {
                        _showEditDialog(post);
                      } else if (value == "delete") {
                        _showDeleteConfirmDialog(post.id);
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 19),
            child: Text(post.content, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          ),
          if (post.mediaUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Image.network(
                api.getCompleteUrl(post.mediaUrls.first),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 19),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => ref.read(feedProvider.notifier).toggleLike(post.id),
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 6),
                Text("${post.likes.length}", style: const TextStyle(fontSize: 14, color: Colors.black87)),
                const SizedBox(width: 18),
                GestureDetector(
                  onTap: () => openPostDetails(post),
                  child: const Icon(Icons.chat_bubble_outline, size: 22, color: Colors.grey),
                ),
                const SizedBox(width: 6),
                Text("${post.comments.length}", style: const TextStyle(fontSize: 14, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Post post) async {
    final controller = TextEditingController(text: post.content);
    final updatedContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Post"),
        content: TextField(controller: controller, maxLines: null, decoration: const InputDecoration(hintText: "Update your post...")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text("Save")),
        ],
      ),
    );

    if (updatedContent != null && updatedContent.isNotEmpty) {
      try {
        await ref.read(feedProvider.notifier).editPost(post.id, updatedContent);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Edit failed: $e")));
      }
    }
  }

  void _showDeleteConfirmDialog(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Post"),
        content: const Text("Are you sure you want to delete this post?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(feedProvider.notifier).deletePost(postId);
    }
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text("Notifications"),
      ),
      body: const Center(
        child: Text("No new notifications yet."),
      ),
    );
  }
}
