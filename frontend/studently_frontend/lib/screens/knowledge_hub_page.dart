import 'package:flutter/material.dart';
import '../widgets/custom_nav_bar.dart';
import 'repository_user_page.dart';
import 'chat_page.dart';

class KnowledgeHubPage extends StatefulWidget {
  const KnowledgeHubPage({super.key});

  @override
  State<KnowledgeHubPage> createState() => _KnowledgeHubPageState();
}

class _KnowledgeHubPageState extends State<KnowledgeHubPage> {
  final TextEditingController _searchController = TextEditingController();
  final Color blue = const Color(0xFF1976D2);

  // Example repository data
  final List<Map<String, dynamic>> repositories = [
    {
      "course": "Database Systems",
      "code": "CS-303",
      "groupChat": "DB Study Group",
      "members": 25,
      "files": 48,
    },
    {
      "course": "Artificial Intelligence",
      "code": "CS-401",
      "groupChat": "AI Learners",
      "members": 32,
      "files": 60,
    },
    {
      "course": "Software Engineering",
      "code": "CS-302",
      "groupChat": "SE Collaborators",
      "members": 20,
      "files": 37,
    },
  ];

  List<Map<String, dynamic>> filteredRepositories = [];

  @override
  void initState() {
    super.initState();
    filteredRepositories = List.from(repositories);
    _searchController.addListener(_filterRepositories);
  }

  void _filterRepositories() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredRepositories = repositories
          .where((repo) => repo["course"].toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0.6,
        backgroundColor: Colors.white,
        title: const Text(
          "Knowledge Hub",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                hintText: "Search courses...",
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // Repository List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredRepositories.length,
              itemBuilder: (context, index) {
                final repo = filteredRepositories[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        repo["course"],
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        repo["code"],
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Repository button
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RepositoryUserPage(
                                    courseName: repo["course"],
                                    courseCode: repo["code"],
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: const Text("Repository"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),

                          // Group Chat button
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatPage(
                                    chatName: repo["groupChat"],
                                    isGroup: true,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.forum_outlined, size: 18),
                            label: const Text("Group Chat"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: blue,
                              side: BorderSide(color: blue),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomNavBar(currentIndex: 3),
    );
  }
}
