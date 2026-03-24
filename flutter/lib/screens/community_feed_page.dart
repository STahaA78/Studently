import '../repositories/post.dart';
import '../models/post.dart';
import 'package:studently/services/firebase_auth.dart'; 
import 'package:flutter/material.dart';
import 'direct_messages_page.dart';
import '../widgets/custom_nav_bar.dart';
import 'post_details_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studently/utils/constants.dart';
import '../screens/user_profile_page.dart';
import '../screens/profile_main.dart';
import '../services/api.dart';
class CommunityFeedPage extends StatefulWidget {
  const CommunityFeedPage({super.key});

  @override
  State<CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<CommunityFeedPage> {
  final Color blue = const Color(0xFF1976D2);
  final ApiService api = ApiService();
  final PostRepository postRepository = PostRepository();

  int skip = 0;
  final int limit = 10;
  bool isFetchingMore = false;
  bool hasMorePosts = true ;
  List<Post> posts = [];
  bool isLoading = true;
  final ScrollController scrollController = ScrollController();
  final Map<String, bool> likedPosts = {};
  final Map<String, int> likeCounts = {};

  @override
  void initState() {
    super.initState();
    loadFeed();
    scrollController.addListener(() {
      if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent - 200 &&
          !isFetchingMore &&
          hasMorePosts) {
        loadMorePosts();
      }
    });
  }

  Future<void> loadFeed() async {
    skip = 0;
    hasMorePosts = true;
    try {

      final data = await postRepository.getFeed();

      final currentUser = authService.value.currentUser?.uid;

      setState(() {

        posts = data;
        likedPosts.clear();
        likeCounts.clear();

        for (var post in posts) {

          likeCounts[post.id] = post.likes.length;

          likedPosts[post.id] = post.likes.contains(currentUser);

        }
        isLoading = false;

      });

    } catch (e) {

      debugPrint("Feed error: $e");

      setState(() => isLoading = false);

    }
  }
  Future<void> loadMorePosts() async {

  if (isFetchingMore || !hasMorePosts) return;

  isFetchingMore = true;

  try {

    skip += limit;

    final newPosts = await postRepository.getFeed(skip: skip, limit: limit);

    if (newPosts.isEmpty) {
      hasMorePosts = false;
    }

    setState(() {
      posts.addAll(newPosts);
    });

  } catch (e) {
    debugPrint("Pagination error: $e");
  }

  isFetchingMore = false;

}
  Future<void> deletePost(String postId, int index) async {

    try {

      await postRepository.deletePost(postId);

      setState(() {
        posts.removeAt(index);
      });

    } catch (e) {

      debugPrint("Delete error: $e");

    }

  }



  Future<void> toggleLike(String postId) async {

    try {

await postRepository.likePost(postId);

setState(() {

      final postIndex = posts.indexWhere((p) => p.id == postId);

      if (postIndex != -1) {

        final post = posts[postIndex];

        final currentUser = authService.value.firebaseAuth.currentUser?.uid;

        if (post.likes.contains(currentUser)) {
          post.likes.remove(currentUser);
        } else {
          post.likes.add(currentUser!);
        }

        likeCounts[postId] = post.likes.length;

        likedPosts[postId] = post.likes.contains(currentUser);

      }

});

    } catch (e) {

      debugPrint("Like error: $e");

    }
  }

  String formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  Future<void> openPostDetails(int index) async {

    final updatedPost = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailsPage(
          postData: posts[index],
        ),
      ),
    );

    if (updatedPost != null && updatedPost is Post) {
      setState(() {
        posts[index] = updatedPost;
      });
    }

  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,

    body: SafeArea(
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ScrollConfiguration(
              behavior:
                  ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: RefreshIndicator(
              onRefresh: loadFeed,  
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
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.black,
                          size: 26,
                        ),
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
                          Icons.mail_outline_rounded,
                          color: Colors.black,
                          size: 26,
                        ),
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

                  /// POSTS
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = posts[index];

                        final bool isLiked =
                            likedPosts[post.id] ?? false;

                        final int likes =
                            likeCounts[post.id] ?? post.likes.length;

                        final int comments = post.comments.length;

                          return _buildPostCard(
                            postId: post.id,
                            index: index,
                            name: post.authorName,
                            time: formatTime(post.timestamp),
                            title: null,
                            description: post.content,
                            image: null,
                            isLiked: isLiked,
                            likes: likes,
                            comments: comments,
                            onCommentTap: () => openPostDetails(index),
                          
                        );
                      },
                      childCount: posts.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
    ),

    /// NAVIGATION BAR (contains + post button)
    bottomNavigationBar: const CustomNavBar(currentIndex: 0),
  );
}

Widget _buildPostCard({
  required String postId,
  required int index,
  required String name,
  required String time,
  String? image,
  String? title,
  required String description,
  required bool isLiked,
  required int likes,
  required int comments,
  required VoidCallback onCommentTap,
}) {

  final post = posts[index];
  final currentUserId = authService.value.currentUser?.uid;

  void openProfile() {

    if (post.authorId == currentUserId) {

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ProfilePage(),
        ),
      );

    } else {

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfilePage(
            userId: post.authorId,
          ),
        ),
      );

    }

  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.only(top: 12, bottom: 12),
    decoration: const BoxDecoration(color: Colors.white),

    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// USER INFO + DELETE MENU
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
                      child: Text(
                        name.isNotEmpty ? name[0] : "?",
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Text(
                          name,
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
                  ],
                ),
              ),

              /// DELETE MENU (ONLY FOR OWN POSTS)
              if (post.authorId == currentUserId)
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: "edit",
                      child: Text("Edit"),
                    ),
                    PopupMenuItem(
                      value: "delete",
                      child: Text("Delete"),
                    ),
                  ],
                  onSelected: (value) async {

                    if (value == "edit") {

                      final controller = TextEditingController(text: description);

                      final updated = await showDialog(
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
                                  Navigator.pop(context, controller.text.trim());
                                },
                                child: const Text("Save"),
                              ),

                            ],

                          );

                        },
                      );

                      if (updated != null && updated.isNotEmpty) {

                        try {

                          await postRepository.editPost(postId, updated);

                        setState(() {
                          posts[index] = Post(
                            id: posts[index].id,
                            authorId: posts[index].authorId,
                            authorName: posts[index].authorName,
                            timestamp: posts[index].timestamp,
                            likes: posts[index].likes,
                            comments: posts[index].comments,
                            mediaUrls: posts[index].mediaUrls,
                            content: updated,
                          );
                        });

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
                          content: const Text("Are you sure you want to delete this post?"),
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
                        deletePost(postId, index);
                      }

                    }

                  }
                ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        /// POST TEXT
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 19),
          child: Text(
            description,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
        ),

        /// IMAGE
        if (post.mediaUrls.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Image.network(
              api.getCompleteUrl(post.mediaUrls.first),
              fit: BoxFit.cover,
            ),
          ),

        const SizedBox(height: 12),

        /// LIKE + COMMENT
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 19),
          child: Row(
            children: [

              GestureDetector(
                onTap: () => toggleLike(postId),
                child: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.grey,
                  size: 22,
                ),
              ),

              const SizedBox(width: 6),

              Text(
                "$likes",
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(width: 18),

              GestureDetector(
                onTap: onCommentTap,
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 22,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(width: 6),

              Text(
                "$comments",
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
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

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
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