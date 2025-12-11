import 'package:flutter/material.dart';
import '../widgets/custom_nav_bar.dart';
import 'post_details_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Color blue = const Color(0xFF1976D2);

  final List<Map<String, dynamic>> posts = [
    {
      "title": "Join me for Group Study Session",
      "image": "assets/images/group_study.jpg",
      "likes": 123,
      "comments": 2,
      "time": "2 days ago",
      "description":
          "Let's collaborate on upcoming exams and help each other improve.",
      "name": "Moiz Pasha",
    },
    {
      "title": "AI Research Collaboration",
      "image": "assets/images/group_study.jpg",
      "likes": 98,
      "comments": 5,
      "time": "1 week ago",
      "description":
          "Looking for AI enthusiasts to collaborate on a paper for our next conference!",
      "name": "Moiz Pasha",
    },
    {
      "title": "New Flutter Project Released!",
      "image": "assets/images/group_study.jpg",
      "likes": 210,
      "comments": 9,
      "time": "3 days ago",
      "description":
          "Just finished my new Flutter UI design — would love feedback!",
      "name": "Moiz Pasha",
    },
    {
      "title": "Web Development Bootcamp",
      "image": "assets/images/group_study.jpg",
      "likes": 167,
      "comments": 3,
      "time": "5 days ago",
      "description":
          "Attended an amazing bootcamp on Next.js and React — sharing resources soon!",
      "name": "Moiz Pasha",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final List<String> interests = [
      "AI & ML",
      "Data Science",
      "Web Development",
      "Blockchain",
      "Cybersecurity",
      "Cloud Computing"
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8), // distance below AppBar
          child: SizedBox(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),

            // Avatar & Info
            CircleAvatar(
              radius: 45,
              backgroundColor: Colors.grey.shade400,
              child: const Text(
                "MP",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Moiz Pasha",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Computer Science, Batch 2022",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 6),

            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.people_alt_rounded, color: Colors.blue),
              label: const Text(
                "35 Connections",
                style: TextStyle(color: Colors.blue),
              ),
            ),

            const SizedBox(height: 12),

            // Interests
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: interests
                  .map((interest) => Chip(
                        label: Text(interest,
                            style: const TextStyle(color: Colors.white)),
                        backgroundColor: blue,
                      ))
                  .toList(),
            ),

            const SizedBox(height: 16),

            // Edit Profile Button ✅ (Restored)
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Edit Profile feature coming soon!"),
                  ),
                );
              },
              icon: Icon(Icons.edit, color: blue),
              label: Text(
                "Edit Profile",
                style: TextStyle(color: blue, fontWeight: FontWeight.w500),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: blue, width: 1.2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 20),

            // Posts Section
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Posts",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Grid of Posts
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Two per row
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, index) {
                final post = posts[index];
                return _buildPostCard(context, post);
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomNavBar(currentIndex: 4),
    );
  }

  Widget _buildPostCard(BuildContext context, Map<String, dynamic> post) {
    return GestureDetector(
      onTap: () async {
        final updatedPost = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailsPage(postData: post),
          ),
        );

        if (updatedPost != null) {
          setState(() {
            post["likes"] = updatedPost["likes"];
            post["comments"] = updatedPost["comments"];
            post["isLiked"] = updatedPost["isLiked"];
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.asset(
                post["image"],
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                post["title"],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const Spacer(),

            // Likes and comments row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.favorite,
                      color: (post["isLiked"] ?? false)
                          ? Colors.red
                          : Colors.grey,
                      size: 18),
                  const SizedBox(width: 3),
                  Text("${post["likes"]}"),
                  const SizedBox(width: 8),
                  const Icon(Icons.chat_bubble_outline,
                      color: Colors.grey, size: 18),
                  const SizedBox(width: 3),
                  Text("${post["comments"]}"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
