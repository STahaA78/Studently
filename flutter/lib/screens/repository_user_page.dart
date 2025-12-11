import 'package:flutter/material.dart';
import '../widgets/custom_nav_bar.dart';

class RepositoryUserPage extends StatefulWidget {
  final String courseName;
  final String courseCode;

  const RepositoryUserPage({
    super.key,
    required this.courseName,
    required this.courseCode,
  });

  @override
  State<RepositoryUserPage> createState() => _RepositoryUserPageState();
}

class _RepositoryUserPageState extends State<RepositoryUserPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final Map<String, List<Map<String, String>>> repositoryData = {
    "Quizzes": [
      {"title": "US-Fall-2022-A", "date": "Oct 26, 2023"},
      {"title": "S-Fall-2022-B", "date": "Nov 02, 2023"},
      {"title": "S-Spring-2022-C", "date": "Nov 10, 2023"},
    ],
    "Past Papers": [
      {"title": "Midterm-2022", "date": "Dec 01, 2022"},
      {"title": "Final-2023", "date": "Jun 12, 2023"},
    ],
    "Lectures": [
      {"title": "Lecture 1 - Introduction", "date": "Jan 05, 2024"},
      {"title": "Lecture 2 - ER Models", "date": "Jan 12, 2024"},
    ],
    "Books": [
      {"title": "Database Systems - Silberschatz", "date": "2022 Edition"},
      {"title": "SQL for Beginners", "date": "2023 Edition"},
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final Color blue = const Color(0xFF1976D2);
    return DefaultTabController(
      length: 4, // number of tabs
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            children: [
              Text(
                widget.courseName,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              Text(
                widget.courseCode,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: TabBar(
              controller: _tabController, // optional if using DefaultTabController
              labelColor: blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: blue,
              tabs: const [
                Tab(text: "Quizzes"),
                Tab(text: "Papers"),
                Tab(text: "Lectures"),
                Tab(text: "Books"),
              ],
            ),
          ),
        ),

        body: TabBarView(
          controller: _tabController, // optional
          children: [
            _buildFileList("Quizzes"),
            _buildFileList("Past Papers"),
            _buildFileList("Lectures"),
            _buildFileList("Books"),
          ],
        ),

        bottomNavigationBar: const CustomNavBar(currentIndex: 3),
      ),
    );

  }

  Widget _buildFileList(String category) {
    final files = repositoryData[category] ?? [];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.insert_drive_file,
                    color: Color(0xFF1976D2), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file["title"]!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      file["date"]!,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
