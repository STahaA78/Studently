import 'package:flutter/material.dart';
import '../widgets/custom_nav_bar.dart';
import 'package:studently/models/course.dart';
import 'package:studently/repositories/course.dart';
import 'knowledge_hub_courses.dart';
//import 'chat_page.dart';

class KnowledgeHubPage extends StatefulWidget {
  const KnowledgeHubPage({super.key});

  @override
  State<KnowledgeHubPage> createState() => _KnowledgeHubPageState();
}

class _KnowledgeHubPageState extends State<KnowledgeHubPage> {
  final TextEditingController _searchController = TextEditingController();
  final Color blue = const Color(0xFF1976D2);

  late Future<List<Course>> _coursesFuture;
  List<Course> allCourses = [];
  List<Course> filteredCourses = [];
  bool isInitialized = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _coursesFuture = CourseRepository().fetchAllCourses();
    _searchController.addListener(_filterCourses);
  }

  void _filterCourses() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredCourses = allCourses
        .where((course) => course.name.toLowerCase().contains(query) || course.code.toLowerCase().contains(query))
        .toList();
    });
  }
  void _scrollToLetter(String letter) {
    if (!mounted) return;
    
    // Wait a frame if controller isn't ready yet
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _performScroll(letter);
        }
      });
      return;
    }
    
    _performScroll(letter);
  }

  void _performScroll(String letter) {
    if (filteredCourses.isEmpty) return;

    int index = filteredCourses.indexWhere(
      (course) => course.name.toUpperCase().startsWith(letter)
    );

    if (index != -1) {
      try {
        double offset = 200 + (index * 145.0); 
        double maxScroll = _scrollController.position.maxScrollExtent;
        double targetOffset = offset > maxScroll ? maxScroll : offset;

        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } catch (e) {
        debugPrint('Scroll error: $e');
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            FutureBuilder(
              future: _coursesFuture,
              builder: (context, asyncSnapshot) {
                //Loading State
                if (asyncSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                //Error State
                if (asyncSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_off_rounded, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 24),
                          
                          const Text(
                            "Connection Issue",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "We couldn't reach our Backend. Please check your internet and try again.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                          const SizedBox(height: 32),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _coursesFuture = CourseRepository().fetchAllCourses();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                              ),
                              child: const Text("Try Again", style: TextStyle(fontSize: 18, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                //Data State
                if (asyncSnapshot.hasData) {
                  allCourses = asyncSnapshot.data!;
                  if (!isInitialized || _searchController.text.isEmpty) {
                    filteredCourses = allCourses;
                  }
                  isInitialized = true;
                }
                
                return ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Collapsible AppBar
                      SliverAppBar(
                        backgroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        elevation: 0,
                        floating: true,
                        snap: true,
                        pinned: false,
                        centerTitle: true,
                        title: const Text(
                          "Knowledge Hub",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                        bottom: PreferredSize(
                          preferredSize: const Size.fromHeight(8),
                          child: const SizedBox(),
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
                            final course = filteredCourses[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.grey.shade300),
                                color: Colors.white,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    course.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    course.code,
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
                                                course: course,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.folder_open, size: 18
                                        ),
                                        label: const Text("Repository"),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          backgroundColor: blue,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          // Navigator.push(
                                          //   context,
                                          //   MaterialPageRoute(
                                          //     builder: (_) => ChatPage(
                                          //       chatName: "${course.name} ${course.code} Group",
                                          //       isGroup: true,
                                          //     ),
                                          //   ),
                                          // );
                                        },
                                        icon: const Icon(Icons.forum_outlined, size: 18),
                                        label: const Text("Group Chat"),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          childCount: filteredCourses.length,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  ),
                );
              }
            ),            
            if (isInitialized && 
                filteredCourses.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 30, 
                  margin: const EdgeInsets.only(right: 0, top: 130, bottom: 100), 
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("").map((letter) {
                      return GestureDetector(
                        onTap: () => _scrollToLetter(letter),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 5, top:1.5, bottom:1.5),
                          child: Text(
                            letter,
                            style: TextStyle(
                              color: blue,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomNavBar(currentIndex: 3),
    );
  }
}