import 'package:flutter/material.dart';
import 'dart:math';

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
    for (int i = 0; i < 15; i++) {
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
        "comments": random.nextInt(10) + 1,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0.8,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Image.asset(
              'assets/images/studently_logo.png',
              height: 26,
            ),
            const SizedBox(width: 6),
            Text(
              'Studently',
              style: TextStyle(
                fontSize: 22,
                color: blue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded,
                color: Colors.black, size: 26),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline_rounded,
                color: Colors.black, size: 26),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MessagesPage()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final bool isLiked = likedPosts[index] ?? false;
          final int likes = likeCounts[index] ?? post["likes"];
          final int comments = post["comments"];

          return _buildPostCard(
            index: index,
            name: post["name"],
            time: post["time"],
            image: post["image"],
            title: post["title"],
            description: post["description"],
            isLiked: isLiked,
            likes: likes,
            comments: comments,
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Feed"),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt), label: "Connect"),
          BottomNavigationBarItem(
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFF1976D2),
              child: Icon(Icons.add, color: Colors.white, size: 20),
            ),
            label: "Post",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "Hub"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
                child: Text(
                  name[0],
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
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
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (title != null) const SizedBox(height: 6),

          Text(
            description,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
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
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black87)),
                  const SizedBox(width: 18),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Comments feature coming soon!"),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Icon(Icons.chat_bubble_outline,
                        size: 22, color: Colors.grey),
                  ),
                  const SizedBox(width: 6),
                  Text("$comments",
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black87)),
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

// Dummy pages for navigation
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: const Center(
        child: Text("No new notifications yet."),
      ),
    );
  }
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Messages")),
      body: const Center(
        child: Text("No new messages yet."),
      ),
    );
  }
}
