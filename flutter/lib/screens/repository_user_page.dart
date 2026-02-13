import 'package:flutter/material.dart';
import 'package:studently/screens/view_resource_page.dart';
import '../widgets/custom_nav_bar.dart';
import 'package:studently/repositories/resource.dart';
import 'package:studently/models/resource.dart';
import 'package:studently/models/course.dart';
import 'package:studently/logger.dart';

class RepositoryUserPage extends StatefulWidget {
  final Course course;

  const RepositoryUserPage({
    super.key,
    required this.course,
  });

  @override
  State<RepositoryUserPage> createState() => _RepositoryUserPageState();
}

class _RepositoryUserPageState extends State<RepositoryUserPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<ResourceGroup> _resourceGroupFuture;
  ResourceGroup? _resourceGroupFetched;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _resourceGroupFuture = ResourceRepository().fetchResourcesByCourse(widget.course.code);
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
                widget.course.name,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              Text(
                widget.course.code,
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
                Tab(text: "Finals"),
                Tab(text: "Midterms"),
                Tab(text: "Quizzes"),
                Tab(text: "Books"),
              ],
            ),
          ),
        ),

        body: FutureBuilder(
          future: _resourceGroupFuture,
          builder:(context, asyncSnapshot) {
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
                              _resourceGroupFuture = ResourceRepository().fetchResourcesByCourse(widget.course.code);
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
              //Any commands to process data can be added here
              isInitialized = true;
              _resourceGroupFetched = asyncSnapshot.data!;
            }
            return TabBarView(
              controller: _tabController,
              children: [
                _buildFileList('final'),
                _buildFileList('midterm'),
                _buildFileList('quiz'),
                _buildFileList('book'),
              ],
            );
         },
        ),

        bottomNavigationBar: const CustomNavBar(currentIndex: 3),
      ),
    );

  }
  // 1. Update the signature to accept the actual List
  Widget _buildFileList(String resourceType) {
    final entries = _resourceGroupFetched?.resources[resourceType] ?? [];
    if (entries.isEmpty) {
      Map<String, String> resourceNames = {
        'final': 'Finals',
        'quiz': 'Quizzes',
        'midterm': 'Midterms',
        'book': 'Books',
      };
      return Center(
        child: Text("No ${resourceNames[resourceType]} Found.",
            style: const TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final item = entries[index];
        
        return InkWell(
          onTap: () {
            // Handle file tap, e.g., open or download the file
            logger.i("Tapped on resource: Year ${item.year} - ${item.semester} - ID: ${item.id}");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PdfGalleryScreen(
                  resources: entries,
                  initialIndex: index,
                ),
              ),
            );
          },
          child:
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.20),
                  blurRadius: 4,
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
                        "Year ${item.year} - ${item.semester}",
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      if (item.instructorName != null && item.instructorName!.isNotEmpty)
                        Text(
                          item.instructorName!,
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          )
        );
      },
    );
  }
}