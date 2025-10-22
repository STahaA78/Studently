import 'package:flutter/material.dart';
import '../widgets/custom_nav_bar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Color blue = const Color(0xFF1976D2);

  bool isLiked = false;
  int likeCount = 123;

  void toggleLike() {
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });
  }

  void showComments() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => _buildCommentsSheet(),
    );
  }

  Widget _buildCommentsSheet() {
    final TextEditingController commentController = TextEditingController();
    final List<String> comments = [
      "This sounds like a great idea!",
      "Count me in for the study session!",
    ];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 20,
      ),
      child: StatefulBuilder(
        builder: (context, setModalState) {
          void addComment() {
            if (commentController.text.trim().isEmpty) return;
            setModalState(() {
              comments.add(commentController.text.trim());
              commentController.clear();
            });
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Comments",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey.shade300,
                        child: const Icon(Icons.person, color: Colors.black54),
                      ),
                      title: Text(comments[index]),
                    );
                  },
                ),
              ),
              const Divider(thickness: 0.5),
              Row(
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
                            vertical: 10, horizontal: 16),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: blue),
                    onPressed: addComment,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

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
        elevation: 0.8,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),

            // Avatar & Basic Info
            CircleAvatar(
              radius: 45,
              backgroundColor: Colors.grey.shade400,
              child: const Text(
                "MP",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
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
                        label: Text(
                          interest,
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: blue,
                      ))
                  .toList(),
            ),

            const SizedBox(height: 16),

            // Edit Profile Button
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
                    color: Colors.black),
              ),
            ),
            const SizedBox(height: 12),

            _buildPostCard(),
          ],
        ),
      ),
      bottomNavigationBar: const CustomNavBar(currentIndex: 4),
    );
  }

  Widget _buildPostCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/group_study.jpg',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Join me for Group Study Session",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text("2 days ago", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: toggleLike,
                child: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 4),
              Text("$likeCount Likes"),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: showComments,
                child: const Icon(Icons.chat_bubble_outline,
                    size: 20, color: Colors.grey),
              ),
              const SizedBox(width: 4),
              const Text("2 comments"),
            ],
          ),
        ],
      ),
    );
  }
}
