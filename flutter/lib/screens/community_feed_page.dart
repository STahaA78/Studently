import 'package:flutter/material.dart';
import 'dart:math';
import 'direct_messages_page.dart';
import '../widgets/custom_nav_bar.dart';
import 'post_details_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studently/utils/constants.dart';

class CommunityFeedPage extends StatefulWidget {
  const CommunityFeedPage({super.key});

  @override
  State<CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<CommunityFeedPage> {
  final Color blue = const Color(0xFF1976D2);
  final Random random = Random();

  final List<Map<String, dynamic>> posts = [];
  final Map<int, bool> likedPosts = {};
  final Map<int, int> likeCounts = {};

  @override
  void initState() {
    super.initState();

    // Generate sample random posts
    for (int i = 0; i < 10; i++) {
      posts.add({
        "name": ["Moiz Pasha", "Taha Ahmed", "Sara Malik", "Ali Khan", "Fatima Noor"][random.nextInt(5)],
        "time": "${random.nextInt(6) + 1} hours ago",
        "title": random.nextBool() ? "Discussion on Flutter Project ${random.nextInt(20)}" : null,
        "description": [
          "Hey everyone! Let's form a study group for tomorrow's lab session.",
          "Does anyone know how to fix the Android emulator issue?",
          "Looking for partners to collaborate on a new AI project!",
          "I'm sharing my notes for today's lecture. Hope it helps!",
          "Need suggestions on improving my Flutter UI layout."
        ][random.nextInt(5)],
        "likes": random.nextInt(40) + 1,
        "comments": random.nextInt(5) + 1,
        "image": random.nextBool() ? "assets/images/group_study.jpg" : null,
      });
    }
  }

  void toggleLike(int index) {
    setState(() {
      likedPosts[index] = !(likedPosts[index] ?? false);
      likeCounts[index] = (likeCounts[index] ?? posts[index]["likes"]) +
          (likedPosts[index]! ? 1 : -1);
    });
  }

  Future<void> openPostDetails(int index) async {
    // Navigate and wait for updates
    final updatedPost = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailsPage(postData: Map<String, dynamic>.from(posts[index])),
      ),
    );

    if (updatedPost != null) {
      setState(() {
        posts[index] = updatedPost;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isLandscape = screenSize.width > screenSize.height;
    final double maxContentWidth = isLandscape ? 600 : screenSize.width * 0.95;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [                  
            Padding(
              padding: const EdgeInsets.only(right: AppStyle.logoSize - AppStyle.titleFontSize), // Visual Enhancement
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/logo.svg',
                    height: AppStyle.logoSize,
                  ),
                  Text(
                    'Studently',
                    style: GoogleFonts.poppins(
                      color: blue,
                      fontSize: AppStyle.titleFontSize,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.black, size: 26),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline_rounded, color: Colors.black, size: 26),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DirectMessagesPage()));
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(12), // distance below AppBar
          child: Column(
            children: [
              SizedBox(height: 8), // how far down you want the line
              Container(
                height: 1,
                color: Color(0xFFE0E0E0),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final bool isLiked = likedPosts[index] ?? false;
              final int likes = likeCounts[index] ?? post["likes"];
              final int comments = post["comments"];

              return GestureDetector(
                onTap: () => openPostDetails(index),
                child: _buildPostCard(
                  index: index,
                  name: post["name"],
                  time: post["time"],
                  image: post["image"],
                  title: post["title"],
                  description: post["description"],
                  isLiked: isLiked,
                  likes: likes,
                  comments: comments,
                  onCommentTap: () => openPostDetails(index),
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: const CustomNavBar(currentIndex: 0),
    );
  }

  Widget _buildPostCard({
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== User Info
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                child: Text(name[0],
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(time, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(image, fit: BoxFit.cover),
            ),
          if (image != null) const SizedBox(height: 10),

          if (title != null)
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (title != null) const SizedBox(height: 6),

          Text(description, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => toggleLike(index),
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.grey,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text("$likes",
                      style: const TextStyle(fontSize: 14, color: Colors.black87)),
                  const SizedBox(width: 18),
                  GestureDetector(
                    onTap: onCommentTap,
                    child: const Icon(Icons.chat_bubble_outline, size: 22, color: Colors.grey),
                  ),
                  const SizedBox(width: 6),
                  Text("$comments",
                      style: const TextStyle(fontSize: 14, color: Colors.black87)),
                ],
              ),
              const Icon(Icons.share_outlined, size: 22, color: Colors.grey),
            ],
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(12), // distance below AppBar
          child: Column(
            children: [
              SizedBox(height: 8), // how far down you want the line
              Container(
                height: 1,
                color: Color(0xFFE0E0E0),
              ),
            ],
          ),
        ),
      ),
      body: const Center(child: Text("No new notifications yet.")),
    );
  }
}
