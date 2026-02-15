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
    {
      "course": "Computer Networks",
      "code": "CS-404",
      "groupChat": "CN Collaborators",
      "members": 20,
      "files": 12,
    },
    {
      "course": "Linear Algebra",
      "code": "MT-302",
      "groupChat": "LA Collaborators",
      "members": 20,
      "files": 10,
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
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              floating: true,
              snap: true,
              centerTitle: true,
              title: const Text(
                "Knowledge Hub",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),

            // Search bar
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    hintText: "Search courses...",
                  ),
                ),
              ),
            ),

            // Repository List
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final repo = filteredRepositories[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(color: Colors.white),
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
                            OutlinedButton.icon(
                              onPressed: () {
                                // ---------------------------------------------------------
                                // FIXED: currentUserId removed to match new ChatPage constructor
                                // ---------------------------------------------------------
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatPage(
                                      conversationId: "group_${repo["code"]}", 
                                      otherUserId: "group", 
                                      otherUserName: repo["groupChat"], 
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
                childCount: filteredRepositories.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
      bottomNavigationBar: const CustomNavBar(currentIndex: 3),
    );
  }
}