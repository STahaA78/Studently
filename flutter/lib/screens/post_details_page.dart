import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../models/post.dart';
import '../repositories/post.dart';
import 'profile_page.dart';
import 'user_profile_page.dart';

class PostDetailsPage extends StatefulWidget {
  final Post postData;

  const PostDetailsPage({
    super.key,
    required this.postData,
  });

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {

  late Post post;
  String? currentUserId;

  final TextEditingController commentController = TextEditingController();
  final PostRepository repository = PostRepository();

  bool isSending = false;

  @override
  void initState() {
    super.initState();
    post = widget.postData;
    currentUserId = authService.value.firebaseAuth.currentUser?.uid;
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

      await repository.addComment(post.id, text);

      setState(() {

        final uid = authService.value.currentUser?.uid ?? "";

        post.comments.add(
          Comment(
            userId: uid,
            username: "You",
            text: text,
            timestamp: DateTime.now().toUtc(),
          ),
        );

        commentController.clear();

      });

    } catch (e) {

      debugPrint("Comment error: $e");

    }

    setState(() => isSending = false);
  }

  /// ---------------- DELETE COMMENT ----------------
  Future<void> deleteComment(Comment comment) async {

    final index = post.comments.indexOf(comment);

    try {

      await repository.deleteComment(post.id, index);

      setState(() {
        post.comments.removeAt(index);
      });

    } catch (e) {

      debugPrint("Delete comment error: $e");

    }
  }

  /// ---------------- LIKE ----------------
  void toggleLike() {

    if (currentUserId == null) return;

    setState(() {

      if (post.likes.contains(currentUserId)) {

        post.likes.remove(currentUserId);

      } else {

        post.likes.add(currentUserId!);

      }

    });
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
        MaterialPageRoute(
          builder: (_) => ProfilePage(),
        ),
      );

    } else {

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfilePage(
            userId: userId,
          ),
        ),
      );

    }
  }

  /// ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text(
          "Comments",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
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
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [

                  Expanded(
                    child: TextField(
                      controller: commentController,
                      decoration: InputDecoration(
                        hintText: "Add a comment...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
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
                        : const Icon(
                            Icons.send,
                            color: Color(0xFF1976D2),
                          ),
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
                    child: Text(
                      post.authorName.isNotEmpty ? post.authorName[0] : "?",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
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
                        style: const TextStyle(color: Colors.grey),
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
            child: Text(
              post.content,
              style: const TextStyle(fontSize: 15),
            ),
          ),

          const SizedBox(height: 8),

          /// LIKE + COMMENT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 19),
            child: Row(
              children: [

                GestureDetector(
                  onTap: toggleLike,
                  child: Icon(
                    post.likes.contains(currentUserId)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: post.likes.contains(currentUserId)
                        ? Colors.red
                        : Colors.grey,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 6),
                Text("${post.likes.length}"),

                const SizedBox(width: 12),

                const Icon(
                  Icons.chat_bubble_outline,
                  size: 22,
                  color: Colors.grey,
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
    final displayName = isOwner ? "You" : comment.username;

    return ListTile(

      leading: GestureDetector(
        onTap: () => openProfile(comment.userId),
        child: CircleAvatar(
          backgroundColor: Colors.grey.shade300,
          child: Text(
            displayName[0],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ),

      title: GestureDetector(
        onTap: () => openProfile(comment.userId),
        child: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      subtitle: Text(comment.text),

      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [

          Text(
            formatTime(comment.timestamp),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),

          if (isOwner)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, size: 20),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: "delete",
                  child: Text("Delete"),
                ),
              ],
              onSelected: (value) async {

                if (value == "delete") {

                  final confirm = await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: const Text("Delete Comment"),
                      content: const Text(
                        "Are you sure you want to delete this comment?",
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
                    deleteComment(comment);
                  }

                }

              },
            ),
        ],
      ),
    );
  }
}