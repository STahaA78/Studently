import 'dart:async';
import 'package:studently/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/services/analytics_service.dart';
import 'package:studently/screens/knowledge_hub_upload.dart';
import 'package:studently/screens/knowledge_hub_resource.dart';
import '../widgets/custom_nav_bar.dart';
import 'package:studently/models/knowledge_hub.dart';
import 'package:studently/logger.dart';
import 'package:studently/providers/knowledge_hub_provider.dart';
import 'package:studently/utils/web_utils.dart' as web_utils;

class RepositoryUserPage extends ConsumerStatefulWidget {
  final Course course;

  const RepositoryUserPage({super.key, required this.course});

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
    _tabController = TabController(length: 2, vsync: this);
    unawaited(
      AnalyticsService.logEvent(
        AnalyticsEvents.courseOpen,
        parameters: {
          'course_code': widget.course.code,
          'course_name_length': widget.course.name.length,
          'source': 'repository_page',
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color blue = AppStyle.primaryBlue;
    final resourcesAsyncValue = ref.watch(
      resourcesByCourseProvider(widget.course.code),
    ); // Uses cache first

    return DefaultTabController(
      length: 2, // number of tabs
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
                        fontSize: AppStyle.appBarTitleSize,
                      ),
                    ),
                    Text(
                      widget.course.code,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                actions: [
                  if (kIsWeb & !web_utils.isStandalonePwa())
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.black),
                      onPressed: () async {
                        final refresh = ref.read(
                          refreshResourcesForCourseProvider(widget.course.code),
                        );
                        await refresh();
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.black, size: 28),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddResourcePage(course: widget.course),
                        ),
                      );
                      // Upload page shows success notification, no need for another here
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
        bottomNavigationBar: const CustomNavBar(currentIndex: 4),
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
                  // Invalidate cache and fetch fresh data
                  ref.invalidate(resourcesByCourseProvider(widget.course.code));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
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
        _buildRefreshableFileList('Final', blue),
        _buildRefreshableFileList('Mid', blue),
      ],
    );
  }

  /// Wraps each tab content with RefreshIndicator for pull-to-refresh
  Widget _buildRefreshableFileList(String resourceType, Color blue) {
    return RefreshIndicator(
      onRefresh: () async {
        // Use the custom refresh function from provider
        final refresh = ref.read(
          refreshResourcesForCourseProvider(widget.course.code),
        );
        await refresh();
      },
      child: _buildFileList(resourceType, blue),
    );
  }

  /// Build file list for a specific resource type, grouped by year and semester
  Widget _buildFileList(String resourceType, Color blue) {
    final entries = _resourceGroupFetched?.resources[resourceType] ?? [];
    if (entries.isEmpty) {
      Map<String, String> resourceNames = {
        'Final': 'Finals',
        'Mid': 'Midterms',
      };
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Text(
              "No ${resourceNames[resourceType]} Found.",
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ),
      );
    }

    // Separate miscellaneous items (year=0 and semester='Unknown')
    final miscItems = entries
        .where((e) => e.year == 0 && e.semester == 'Unknown')
        .toList();
    final regularItems = entries
        .where((e) => !(e.year == 0 && e.semester == 'Unknown'))
        .toList();

    // Group regular entries by year, then by semester
    Map<int, Map<String, List<ResourceItem>>> entriesByYearAndSemester = {};
    for (var entry in regularItems) {
      if (!entriesByYearAndSemester.containsKey(entry.year)) {
        entriesByYearAndSemester[entry.year] = {};
      }
      if (!entriesByYearAndSemester[entry.year]!.containsKey(entry.semester)) {
        entriesByYearAndSemester[entry.year]![entry.semester] = [];
      }
      entriesByYearAndSemester[entry.year]![entry.semester]!.add(entry);
    }

    // Sort years in descending order
    final sortedYears = entriesByYearAndSemester.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Miscellaneous section
        if (miscItems.isNotEmpty) ...[
          ExpansionTile(
            title: const Text(
              "Miscellaneous",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 0),
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: miscItems.length,
                itemBuilder: (context, itemIndex) {
                  final item = miscItems[itemIndex];
                  final isLastItem = itemIndex == miscItems.length - 1;

                  return _buildResourceTile(item, entries, isLastItem);
                },
              ),
            ],
          ),
        ],

        // Year sections
        ...sortedYears.map((year) {
          final semesterMap = entriesByYearAndSemester[year]!;
          final sortedSemesters = semesterMap.keys.toList()
            ..sort((a, b) => a.compareTo(b));

          return ExpansionTile(
            title: Text(
              "$year",
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 0),
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
            children: [
              ...sortedSemesters.map((semester) {
                final semesterItems = semesterMap[semester]!;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        top: 4,
                        bottom: 8,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          semester,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: semesterItems.length,
                      itemBuilder: (context, itemIndex) {
                        final item = semesterItems[itemIndex];
                        final isLastItem =
                            itemIndex == semesterItems.length - 1;

                        return _buildResourceTile(item, entries, isLastItem);
                      },
                    ),
                  ],
                );
              }),
            ],
          );
        }),
      ],
    );
  }

  /// Helper method to build individual resource tile
  Widget _buildResourceTile(
    ResourceItem item,
    List<ResourceItem> allEntries,
    bool isLastItem,
  ) {
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            logger.i(
              "Tapped on resource: Year ${item.year} - ${item.semester} - ID: ${item.id}",
            );

            unawaited(
              AnalyticsService.logEvent(
                AnalyticsEvents.resourceOpen,
                parameters: {
                  'course_code': widget.course.code,
                  'resource_id_present': item.id.isNotEmpty,
                  'resource_type': item.type,
                  'semester': item.semester,
                  'year': item.year,
                  'mid_number': item.midNumber ?? 0,
                  'is_solved': item.isSolved ?? false,
                  'platform': kIsWeb ? 'web' : 'native',
                },
              ),
            );

            // For web (non-PWA), open PDF in a new tab
            if (kIsWeb && !web_utils.isStandalonePwa()) {
              try {
                web_utils.openInNewTab(item.fileUrl);
              } catch (e) {
                logger.e('Error opening PDF in new tab: $e');
              }
            } else {
              // For PWA and mobile, use SfPdfViewer
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PdfGalleryScreen(
                    resources: allEntries,
                    initialIndex: allEntries.indexOf(item),
                    courseCode: widget.course.code,
                  ),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.insert_drive_file,
                    color: AppStyle.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.type == 'Mid'
                            ? "${item.midNumber != null ? 'Mid-${item.midNumber}' : ''} ${item.isSolved == true ? 'Solved' : 'Unsolved'}"
                            : (item.isSolved == true ? 'Solved' : 'Unsolved'),
                        style: TextStyle(
                          color: item.isSolved == true
                              ? Colors.green
                              : Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLastItem)
          Divider(
            height: 0.75,
            thickness: 0.75,
            color: Colors.grey[300],
            indent: 30,
            endIndent: 30,
          ),
      ],
    );
  }
}
