import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/screens/knowledge_hub_upload.dart';
import 'package:studently/screens/knowledge_hub_resource.dart';
import '../widgets/custom_nav_bar.dart';
import 'package:studently/models/knowledge_hub.dart';
import 'package:studently/logger.dart';
import 'package:studently/providers/knowledge_hub_provider.dart';

class RepositoryUserPage extends ConsumerStatefulWidget {
  final Course course;

  const RepositoryUserPage({
    super.key,
    required this.course,
  });

  @override
  ConsumerState<RepositoryUserPage> createState() => _RepositoryUserPageState();
}

class _RepositoryUserPageState extends ConsumerState<RepositoryUserPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ResourceGroup? _resourceGroupFetched;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final Color blue = const Color(0xFF1976D2);
    final resourcesAsyncValue = ref.watch(resourcesByCourseProvider(widget.course.code)); // Uses cache first

    return DefaultTabController(
      length: 4, // number of tabs
      child: Scaffold(
        backgroundColor: Colors.white,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                backgroundColor: Colors.white,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                floating: true,
                snap: true,
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
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.black, size: 28),
                    onPressed: () async {
                      final success = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddResourcePage(course: widget.course),
                        ),
                      );
                      if (success == true) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Resource uploaded successfully!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        // Provider was already refreshed in upload page, no need to invalidate here
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                centerTitle: true,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: TabBar(
                    controller: _tabController,
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
            ];
          },
          body: resourcesAsyncValue.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _buildErrorState(context, blue),
            data: (resourceGroup) => _buildResourcesView(resourceGroup, blue),
          ),
        ),
        bottomNavigationBar: const CustomNavBar(currentIndex: 3),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Color blue) {
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
                  // Force refresh the resources for this course
                  ref.read(resourcesCourseFreshProvider(widget.course.code));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25)),
                ),
                child: const Text(
                  "Try Again",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourcesView(ResourceGroup resourceGroup, Color blue) {
    _resourceGroupFetched = resourceGroup;
    if (!isInitialized) {
      isInitialized = true;
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildRefreshableFileList('final', blue),
        _buildRefreshableFileList('midterm', blue),
        _buildRefreshableFileList('quiz', blue),
        _buildRefreshableFileList('book', blue),
      ],
    );
  }

  /// Wraps each tab content with RefreshIndicator for pull-to-refresh
  Widget _buildRefreshableFileList(String resourceType, Color blue) {
    return RefreshIndicator(
      onRefresh: () async {
        // Pull-to-refresh: Force fresh fetch using the fresh provider
        try {
          // This fetches fresh data from API and caches it
          await ref.refresh(resourcesCourseFreshProvider(widget.course.code).future);
          logger.i("[$runtimeType] Refresh completed, got fresh data from API");
          // Now refresh the main provider to update UI with fresh cached data
          await ref.refresh(resourcesByCourseProvider(widget.course.code).future);
          logger.i("[$runtimeType] Main provider refreshed with new cache");
        } catch (e) {
          logger.e("[$runtimeType] Refresh failed: $e");
          rethrow;
        }
      },
      child: _buildFileList(resourceType, blue),
    );
  }

  /// Build file list for a specific resource type
  Widget _buildFileList(String resourceType, Color blue) {
    final entries = _resourceGroupFetched?.resources[resourceType] ?? [];
    if (entries.isEmpty) {
      Map<String, String> resourceNames = {
        'final': 'Finals',
        'quiz': 'Quizzes',
        'midterm': 'Midterms',
        'book': 'Books',
      };
      // Wrap empty state in SingleChildScrollView to make it scrollable for refresh
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Text("No ${resourceNames[resourceType]} Found.",
                style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final item = entries[index];

        return GestureDetector(
          onTap: () {
            // Handle file tap, e.g., open or download the file
            logger.i("Tapped on resource: Year ${item.year} - ${item.semester} - ID: ${item.id}");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PdfGalleryScreen(
                  resources: entries,
                  initialIndex: index,
                  courseCode: widget.course.code,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.20),
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
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      if (resourceType != 'book')
                        Text(
                          item.isSolved == true ? "Solved" : "Unsolved",
                          style: TextStyle(
                            color: item.isSolved == true
                                ? Colors.green
                                : Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      if (resourceType == 'quiz')
                        Text(
                          "Quiz ${item.quizNumber}",
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      Text(
                        "Instructor: ${item.instructorName ?? "Unknown"}",
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}