import 'package:flutter/material.dart';

class PostDetailsPage extends StatefulWidget {
  final Map<String, dynamic> postData;

  const PostDetailsPage({super.key, required this.postData});

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  late Map<String, dynamic> post;
  final TextEditingController _commentController = TextEditingController();
  final List<Map<String, String>> comments = [];

  @override
  void initState() {
    super.initState();
    post = Map<String, dynamic>.from(widget.postData);

    // Simulated starting comments
    comments.addAll([
      {"name": "Danyal Rehman", "time": "1 hour ago", "comment": "That's awesome! Good luck!"},
      {"name": "Ameer Hamza", "time": "50 min ago", "comment": "This is inspiring work!"},
    ]);
  }

  void toggleLike() {
    setState(() {
      post["isLiked"] = !(post["isLiked"] ?? false);
      post["likes"] = (post["likes"] ?? 0) + (post["isLiked"] ? 1 : -1);
    });
  }

  void addComment() {
    if (_commentController.text.trim().isEmpty) return;
    setState(() {
      comments.insert(0, {
        "name": "You",
        "time": "Just now",
        "comment": _commentController.text.trim(),
      });
      post["comments"] = (post["comments"] ?? 0) + 1;
      _commentController.clear();
    });
  }

  @override
  void dispose() {
    Navigator.pop(context, post); // Return updated post data to feed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Post Details",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context, post),
        ),
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
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Post Card
                _buildPostCard(),
                const SizedBox(height: 16),
                ...comments.map((c) => _buildCommentTile(c)).toList(),
              ],
            ),
          ),

          // Add comment input
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
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: "Add a comment...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF1976D2)),
                    onPressed: addComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                child: Text(post["name"][0],
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post["name"],
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(post["time"], style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (post["image"] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(post["image"], fit: BoxFit.cover),
            ),
          const SizedBox(height: 8),
          Text(post["description"], style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: toggleLike,
                child: Icon(
                  (post["isLiked"] ?? false) ? Icons.favorite : Icons.favorite_border,
                  color: (post["isLiked"] ?? false) ? Colors.red : Colors.grey,
                  size: 22,
                ),
              ),
              const SizedBox(width: 6),
              Text("${post["likes"]}"),
              const SizedBox(width: 12),
              const Icon(Icons.chat_bubble_outline, size: 22, color: Colors.grey),
              const SizedBox(width: 6),
              Text("${post["comments"]}"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(Map<String, String> c) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade300,
        child: Text(c["name"]![0],
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
      ),
      title: Text(c["name"]!, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(c["comment"]!),
      trailing: Text(c["time"]!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    );
  }
}
