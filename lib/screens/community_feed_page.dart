import 'package:studently/models/post.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:studently/screens/direct_messages_page.dart';
import 'package:studently/widgets/custom_nav_bar.dart';
import 'package:studently/widgets/notification_badge_icon.dart';
import 'package:studently/screens/post_details_page.dart';
import 'package:studently/screens/notifications_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studently/app_style.dart';
import 'package:studently/screens/profile_main.dart';
import 'package:studently/services/api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/providers/feed_provider.dart';
import 'package:studently/providers/notifications_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:studently/utils/web_utils.dart' as web_utils;

class CommunityFeedPage extends ConsumerStatefulWidget {
  const CommunityFeedPage({super.key});

  @override
  ConsumerState<CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends ConsumerState<CommunityFeedPage> {
  final Color blue = AppStyle.primaryBlue;
  final ApiService api = ApiService();
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Restore scroll position after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        final savedOffset = ref.read(feedScrollProvider);
        if (savedOffset > 0) {
          scrollController.jumpTo(savedOffset);
        }
      }
    });

    scrollController.addListener(() {
      // Save scroll position
      if (scrollController.hasClients) {
        ref.read(feedScrollProvider.notifier).set(scrollController.offset);
      }

      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 200) {
        ref.read(feedProvider.notifier).loadMore();
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

  Future<void> openPostDetails(int index, List<Post> posts) async {
    final updatedPost = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailsPage(postData: posts[index]),
      ),
    );

    if (updatedPost != null && updatedPost is Post) {
      ref.read(feedProvider.notifier).updatePostLocally(updatedPost);
      // Also sync to profile if it's the current user's profile
      final userId = authService.value.currentUser?.uid;
      if (userId != null) {
        ref
            .read(profileFeedProvider(userId).notifier)
            .syncPostUpdate(updatedPost);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(feedProvider);
    final unreadCount = ref.watch(
      notificationProvider.select((s) => s.unreadCount),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: feedAsync.when(
          data: (posts) => ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: RefreshIndicator(
              onRefresh: () => ref.read(feedProvider.notifier).refresh(),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    floating: true,
                    snap: true,
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/images/logo.svg',
                          height: AppStyle.logoSize*0.9,
                          colorFilter: const ColorFilter.mode(
                            AppStyle.primaryBlue,
                            BlendMode.srcIn,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            'Studently',
                            style: GoogleFonts.poppins(
                              color: AppStyle.primaryBlue,
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
                      if (kIsWeb & !web_utils.isStandalonePwa())
                        IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.black,
                          ),
                          iconSize: 25,
                          tooltip: 'Refresh feed',
                          onPressed: () => ref
                              .read(feedProvider.notifier)
                              .refresh(),
                        ),
                      NotificationBadgeIcon(
                        unreadCount: unreadCount,
                        icon: Icons.notifications_none_outlined,
                        iconColor: Colors.black,
                        iconSize: 24,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsPage(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.inbox,
                          color: Colors.black,
                        ),
                        iconSize: 24,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DirectMessagesPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  if (posts.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'No Posts Found',
                          style: const TextStyle(
                            color: Colors.grey,
                          fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final post = posts[index];
                        final currentUser = authService.value.currentUser?.uid;
                        final bool isLiked = post.likes.contains(currentUser);
                        final int likes = post.likes.length;
                        final int comments = post.comments.length;

                        return _buildPostCard(
                          post: post,
                          index: index,
                          name: post.authorName,
                          time: formatTime(post.timestamp),
                          isLiked: isLiked,
                          likes: likes,
                          comments: comments,
                          onCommentTap: () => openPostDetails(index, posts),
                          allPosts: posts,
                        );
                      }, childCount: posts.length),
                    ),
                  if (feedAsync.isLoading && posts.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Error retrieving feed",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We couldn't reach our backend. Refresh to try again.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => ref.read(feedProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text(
                        "Refresh",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppStyle.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const CustomNavBar(currentIndex: 0),
    );
  }

  Widget _buildPostCard({
    required Post post,
    required int index,
    required String name,
    required String time,
    required bool isLiked,
    required int likes,
    required int comments,
    required VoidCallback onCommentTap,
    required List<Post> allPosts,
  }) {
    final currentUserId = authService.value.currentUser?.uid;

    void openProfile() {
      if (post.authorId == currentUserId) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfilePage()),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfilePage(userId: post.authorId)),
        );
      }
    }
    final String? pic = post.authorPic;
    final bool hasPic = pic != null && pic.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: openProfile,
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: hasPic ? CachedNetworkImageProvider(pic) : null,
                          child: hasPic
                              ? null
                              : Text(
                                  name.isNotEmpty ? name[0] : "?",
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                time,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                        final controller = TextEditingController(
                          text: post.content,
                        );
                        final updated = await showDialog<String>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text("Edit Post"),
                              content: TextField(
                                controller: controller,
                                maxLines: null,
                                decoration: const InputDecoration(
                                  hintText: "Update your post...",
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(
                                      context,
                                      controller.text.trim(),
                                    );
                                  },
                                  child: const Text("Save"),
                                ),
                              ],
                            );
                          },
                        );

                        if (updated != null && updated.isNotEmpty) {
                          try {
                            final postRepo = ref.read(postRepositoryProvider);
                            await postRepo.editPost(post.id, updated);
                            final updatedPost = post.copyWith(content: updated);
                            ref
                                .read(feedProvider.notifier)
                                .updatePostLocally(updatedPost);
                            if (currentUserId != null) {
                              ref
                                  .read(
                                    profileFeedProvider(currentUserId).notifier,
                                  )
                                  .syncPostUpdate(updatedPost);
                            }
                          } catch (e) {
                            debugPrint("Edit error: $e");
                          }
                        }
                      }

                      if (value == "delete") {
                        if (!mounted) return;
                        final confirm = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Delete Post"),
                            content: const Text(
                              "Are you sure you want to delete this post?",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  "Delete",
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          ref.read(feedProvider.notifier).deletePost(post.id);
                          if (currentUserId != null) {
                            ref
                                .read(
                                  profileFeedProvider(currentUserId).notifier,
                                )
                                .removePostLocally(post.id);
                          }
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 19),
            child: Text(
              post.content,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),
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
                        crossAxisAlignment: CrossAxisAlignment.center,
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
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 19),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    ref.read(feedProvider.notifier).toggleLike(post.id);
                    if (currentUserId != null) {
                      final updatedPost = post.copyWith(
                        likes: post.likes.contains(currentUserId)
                            ? (List<String>.from(post.likes)
                                ..remove(currentUserId))
                            : (List<String>.from(post.likes)
                                ..add(currentUserId)),
                      );
                      ref
                          .read(profileFeedProvider(currentUserId).notifier)
                          .syncPostUpdate(updatedPost);
                    }
                  },
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.black,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "$likes",
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(width: 18),
                GestureDetector(
                  onTap: onCommentTap,
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    size: 22,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "$comments",
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
