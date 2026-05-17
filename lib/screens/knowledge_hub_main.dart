import 'package:studently/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/custom_nav_bar.dart';
import 'package:studently/models/knowledge_hub.dart';
import 'package:studently/providers/knowledge_hub_provider.dart';
import 'package:studently/screens/knowledge_hub_course.dart';
import 'package:studently/utils/web_utils.dart' as web_utils;

// NEW IMPORTS FOR GROUP CHAT
import 'package:studently/repositories/chat.dart';
import 'package:studently/screens/chat_page.dart';

class KnowledgeHubPage extends ConsumerStatefulWidget {
  const KnowledgeHubPage({super.key});

  @override
  ConsumerState<KnowledgeHubPage> createState() => _KnowledgeHubPageState();
}

class _KnowledgeHubPageState extends ConsumerState<KnowledgeHubPage> {
  final TextEditingController _searchController = TextEditingController();
  final Color blue = AppStyle.primaryBlue;

  List<Course> allCourses = [];
  List<Course> filteredCourses = [];
  bool isInitialized = false;

  final ScrollController _scrollController = ScrollController();

  String? _activeLetter;
  final GlobalKey _alphabetBarKey = GlobalKey();

  static const List<String> _allLetters = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  Map<String, int> _letterIndexMap = {};

  // We measure the first card's height after it renders
  final GlobalKey _firstCardKey = GlobalKey();
  double? _measuredCardHeight;

  // We measure the sliver header (AppBar + search bar) height
  final GlobalKey _headerKey = GlobalKey();
  double? _measuredHeaderHeight;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterCourses);
  }

  void _buildLetterIndexMap() {
    _letterIndexMap = {};
    for (int i = 0; i < filteredCourses.length; i++) {
      final letter = filteredCourses[i].name[0].toUpperCase();
      if (!_letterIndexMap.containsKey(letter)) {
        _letterIndexMap[letter] = i;
      }
    }
  }

  void _filterCourses() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredCourses = allCourses
          .where(
            (course) =>
                course.name.toLowerCase().contains(query) ||
                course.code.toLowerCase().contains(query),
          )
          .toList();
      _buildLetterIndexMap();
    });
  }

  /// Measure card height and header height from the rendered widgets.
  /// Falls back to known constants if not yet rendered.
  void _measureHeights() {
    if (_measuredCardHeight == null) {
      final box =
          _firstCardKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        // include the vertical margin (7 top + 7 bottom = 14)
        _measuredCardHeight = box.size.height + 14;
      }
    }
    if (_measuredHeaderHeight == null) {
      final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        _measuredHeaderHeight = box.size.height;
      }
    }
  }

  void _scrollToLetter(String letter) {
    final index = _letterIndexMap[letter];
    if (index == null || !_scrollController.hasClients) return;

    _measureHeights();

    // Fallback values that match our widget dimensions:
    // card: padding(16)*2 + text ~35 + code ~16 + SizedBox(4) + SizedBox(10) + button ~36 = ~133 + margin 14 = ~147
    final cardH = _measuredCardHeight ?? 147.0;
    // header: AppBar ~56 + bottom padding 8 + search container ~64 (margin 16 + TextField ~48) = ~128
    final headerH = _measuredHeaderHeight ?? 128.0;

    final offset = headerH + (index * cardH);
    final maxScroll = _scrollController.position.maxScrollExtent;

    _scrollController.animateTo(
      offset.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _handleAlphabetPan(Offset globalPosition) {
    final RenderBox? box =
        _alphabetBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localY = globalPosition.dy - box.localToGlobal(Offset.zero).dy;
    final totalHeight = box.size.height;
    final letterHeight = totalHeight / _allLetters.length;

    final idx = (localY / letterHeight).floor().clamp(
      0,
      _allLetters.length - 1,
    );
    final letter = _allLetters[idx];

    if (letter != _activeLetter) {
      setState(() => _activeLetter = letter);
      if (_letterIndexMap.containsKey(letter)) {
        HapticFeedback.selectionClick();
        _scrollToLetter(letter);
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
    final screenHeight = MediaQuery.of(context).size.height;
    final coursesAsyncValue = ref.watch(
      allCoursesProvider,
    ); // Uses cache first, then API

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Use the custom refresh function from provider
            final refresh = ref.read(refreshAllCoursesProvider);
            await refresh();
          },
          child: coursesAsyncValue.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _buildErrorState(context),
            data: (courses) =>
                _buildCoursesView(context, courses, screenHeight),
          ),
        ),
      ),
      bottomNavigationBar: const CustomNavBar(currentIndex: 4),
    );
  }

  Widget _buildErrorState(BuildContext context) {
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
                  ref.invalidate(allCoursesProvider);
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

  Widget _buildCoursesView(
    BuildContext context,
    List<Course> courses,
    double screenHeight,
  ) {
    // Update courses data
    allCourses = courses;
    if (!isInitialized || _searchController.text.isEmpty) {
      filteredCourses = allCourses;
    }
    if (!isInitialized) {
      _buildLetterIndexMap();
      isInitialized = true;
      // Measure after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _measureHeights();
      });
    }

    return Stack(
      children: [
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
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
                    fontWeight: FontWeight.w600,
                    fontSize: AppStyle.appBarTitleSize,
                  ),
                ),
                actions: kIsWeb & !web_utils.isStandalonePwa()
                    ? [
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.black),
                          onPressed: () async {
                            final refresh = ref.read(refreshAllCoursesProvider);
                            await refresh();
                          },
                        ),
                      ]
                    : [],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(8),
                  child: const SizedBox(),
                ),
              ),

              // Wrap search bar in a SliverToBoxAdapter with a key
              // so we can measure the total header height
              SliverToBoxAdapter(
                child: Container(
                  key: _headerKey,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: AppStyle.searchDecoration("Search courses..."),
                  ),
                ),
              ),

              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final course = filteredCourses[index];
                  final isFirst = index == 0;
                  final isLast = index == filteredCourses.length - 1;

                  return Column(
                    children: [
                      Container(
                        key: isFirst ? _firstCardKey : null,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 7,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              course.code,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 40,
                                    child: ElevatedButton.icon(
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
                                        Icons.folder_open,
                                        size: 18,
                                      ),
                                      label: const Text("Repository"),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        backgroundColor: blue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: SizedBox(
                                    height: 40,
                                    child: OutlinedButton.icon(
                                      // CHANGED: Wired up Group Chat backend logic
                                      onPressed: () async {
                                        final convId = await ChatRepository()
                                            .joinCourseGroupChat(course.code);

                                        if (convId != null && context.mounted) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ChatPage(
                                                conversationId: convId,
                                                otherUserId: "GROUP",
                                                otherUserName:
                                                    "${course.name} Group",
                                              ),
                                            ),
                                          );
                                        } else if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "Failed to join group chat.",
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.forum_outlined,
                                        size: 18,
                                      ),
                                      label: const Text("Group Chat"),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        foregroundColor: blue,
                                        side: BorderSide(color: blue),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Divider(
                          height: 0.75,
                          thickness: 0.75,
                          color: Colors.grey[300],
                          indent: 30,
                          endIndent: 30,
                        ),
                    ],
                  );
                }, childCount: filteredCourses.length),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),

        // Alphabet scroll bar
        if (isInitialized && filteredCourses.isNotEmpty)
          Positioned(
            right: 0,
            top: screenHeight * 0.25, // Start a bit below the AppBar
            bottom: screenHeight * 0.15, // End a bit above the bottom nav
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (d) => _handleAlphabetPan(d.globalPosition),
              onPanUpdate: (d) => _handleAlphabetPan(d.globalPosition),
              onPanEnd: (_) => setState(() => _activeLetter = null),
              onTapUp: (_) => setState(() => _activeLetter = null),
              onTapCancel: () => setState(() => _activeLetter = null),
              child: SizedBox(
                key: _alphabetBarKey,
                width: 28,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _allLetters.map((letter) {
                    final isActive = letter == _activeLetter;
                    final hasData = _letterIndexMap.containsKey(letter);

                    return Expanded(
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 80),
                          style: TextStyle(
                            color: hasData ? blue : Colors.grey.shade400,
                            fontSize: isActive ? 17 : 11,
                          ),
                          child: Text(letter),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
