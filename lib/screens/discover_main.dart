import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:studently/models/backend_config.dart';
import 'package:studently/models/user.dart';
import 'package:studently/providers/backend_config_provider.dart';
import 'package:studently/providers/discover_provider.dart';
import 'package:studently/screens/profile_main.dart';
import 'package:studently/widgets/custom_nav_bar.dart';
import 'package:studently/screens/discover_requests.dart';
import 'package:studently/app_style.dart';

class ConnectDiscoverPage extends ConsumerStatefulWidget {
  const ConnectDiscoverPage({super.key});

  @override
  ConsumerState<ConnectDiscoverPage> createState() =>_ConnectDiscoverPageState();
}

class _ConnectDiscoverPageState extends ConsumerState<ConnectDiscoverPage> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final Color primaryBlue = const Color(0xFF0F74C5);
  final ValueNotifier<double> _swipeProgressNotifier = ValueNotifier<double>(
    0.0,
  );

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(discoverConnectProvider.notifier).init();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _swipeProgressNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reload pending count when app resumes (returning from another screen)
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(discoverConnectProvider.notifier).refreshPendingRequests();
    }
  }
  void _clearSearch() {
    _searchController.clear();
    ref.read(discoverConnectProvider.notifier).clearSearch();
  }

  void _runSearch(String query) {
    _searchController.text = query;
    ref.read(discoverConnectProvider.notifier).runSearch(query);
  }

  // ---------------- FILTER PANEL ----------------
  void _showFilterPanel(BuildContext context) {
    final discoverState = ref.read(discoverConnectProvider);
    String? tempDept = discoverState.selectedDepartmentName;
    String? tempBatch = discoverState.selectedBatchYear;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Consumer(
          builder: (context, ref, child) => ref
              .watch(backendConfigProvider)
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text("Error loading config: $e")),
                data: (config) {
                  final batchYears = List<String>.generate(
                    config.batchRange.end - config.batchRange.start + 1,
                    (i) => (config.batchRange.start + i).toString(),
                  );
                  return Container(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(
                          context,
                        ).copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Filter",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => Navigator.pop(context),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                "Department",
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: config.departments.map((dept) {
                                  return FilterChip(
                                    label: Text(dept.name),
                                    selected: tempDept == dept.name,
                                    showCheckmark: false,
                                    backgroundColor: Colors.white,
                                    selectedColor: const Color(0xFF0F74C5),
                                    checkmarkColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: tempDept == dept.name
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                    onSelected: (selected) => setSheetState(() {
                                      tempDept = selected ? dept.name : null;
                                    }),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                "Batch Year",
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: batchYears.map((batch) {
                                  return FilterChip(
                                    label: Text(batch),
                                    selected: tempBatch == batch,
                                    showCheckmark: false,
                                    backgroundColor: Colors.white,
                                    selectedColor: const Color(0xFF0F74C5),
                                    checkmarkColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: tempBatch == batch
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                    onSelected: (selected) => setSheetState(() {
                                      tempBatch = selected ? batch : null;
                                    }),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _swipeProgressNotifier.value = 0.0;
                                        ref
                                            .read(
                                              discoverConnectProvider.notifier,
                                            )
                                            .resetFilters();
                                      },
                                      child: const Text("Reset"),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _swipeProgressNotifier.value = 0.0;
                                        ref
                                            .read(
                                              discoverConnectProvider.notifier,
                                            )
                                            .applyFilters(
                                              departmentName: tempDept,
                                              batchYear: tempBatch,
                                            );
                                      },
                                      child: const Text("Apply"),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
        ),
      ),
    );
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    final discoverState = ref.watch(discoverConnectProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Connect",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          // Refresh button (web only)
          if (kIsWeb)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              tooltip: 'Refresh profiles',
              onPressed:
                  discoverState.isRefreshing
                      ? null
                      : () => ref
                          .read(discoverConnectProvider.notifier)
                          .refreshDiscoverUsers(forceRefresh: true),
            ),
          IconButton(
            icon: Stack(
              children: [
                SvgPicture.asset(
                  'assets/images/friend-requests.svg',
                  height: 22,
                  width: 22,
                  colorFilter: const ColorFilter.mode(
                    Colors.black,
                    BlendMode.srcIn,
                  ),
                ),
                if (discoverState.pendingRequestsCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: Colors.red,
                      child: Text(
                        discoverState.pendingRequestsCount.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RequestsPage()),
              );
              await ref
                  .read(discoverConnectProvider.notifier)
                  .refreshPendingRequests(forceRefresh: true);
              if (result == true) {
                ref
                    .read(discoverConnectProvider.notifier)
                    .refreshDiscoverUsers(forceRefresh: true);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: discoverState.isSearchFocused ? 48 : 0,
                  child: discoverState.isSearchFocused
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: _clearSearch,
                          padding: EdgeInsets.zero,
                        )
                      : null,
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => ref
                        .read(discoverConnectProvider.notifier)
                        .onSearchChanged(value),
                    onTap:
                        () => ref
                            .read(discoverConnectProvider.notifier)
                            .setSearchFocused(true),
                    decoration: AppStyle.searchDecoration("Search Students ")
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: SizedBox(
                    width: !discoverState.isSearchFocused ? 25 : 0,
                    child: !discoverState.isSearchFocused
                        ? IconButton(
                            icon: const Icon(Icons.tune),
                            onPressed: () => _showFilterPanel(context),
                            padding: EdgeInsets.zero,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Visibility(
                  visible:
                      !discoverState.isSearchFocused ||
                      (_searchController.text.isEmpty),
                  maintainState: true,
                  child: _buildCardStack(discoverState),
                ),
                if (discoverState.isSearchFocused &&
                    _searchController.text.isEmpty)
                  _buildRecentSearches(discoverState),
                if (discoverState.isSearchFocused &&
                    _searchController.text.isNotEmpty)
                  _buildSearchResults(discoverState),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomNavBar(currentIndex: 1),
    );
  }

  // ---------------- SEARCH RESULTS LIST ----------------
  Widget _buildSearchResults(DiscoverConnectState state) {
    if (state.students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                "No Students Found",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      itemCount: state.students.length,
      itemBuilder: (context, index) {
        final user = state.students[index];
        return _buildSearchResultItem(user);
      },
    );
  }

  Widget _buildSearchResultItem(User user) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfilePage(userId: user.id)),
        );
        if (result == true && mounted) {
          ref
              .read(discoverConnectProvider.notifier)
              .runSearch(_searchController.text);
        }
      },
      child: Container(
        height: 65,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey[300],
              backgroundImage: user.picture != null && user.picture!.isNotEmpty
                  ? NetworkImage(user.picture!)
                  : null,
              child: user.picture == null || user.picture!.isEmpty
                  ? const Icon(Icons.person, size: 32, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 12),
            // Primary and Secondary text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${user.department?.name ?? 'N/A'} • Batch ${user.batch}",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- RECENT SEARCHES ----------------
  Widget _buildRecentSearches(DiscoverConnectState state) {
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (state.recentSearches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Searches",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap:
                        () =>
                            ref
                                .read(discoverConnectProvider.notifier)
                                .clearRecentSearches(),
                    child: Text(
                      "Clear all",
                      style: TextStyle(color: primaryBlue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ...state.recentSearches.map(
            (search) => GestureDetector(
              onTap: () {
                _runSearch(search);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: Colors.grey, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        search,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => ref
                          .read(discoverConnectProvider.notifier)
                          .removeRecentSearch(search),
                      child: Icon(
                        Icons.close,
                        color: Colors.grey[400],
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- CARD STACK ----------------
  Widget _buildCardStack(DiscoverConnectState state) {
    if (state.isLoading && state.students.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.students.isEmpty) {
      return _buildErrorState();
    }
    if (state.students.isEmpty) {
      return _buildEmptyState('All Caught Up!');
    }
    if (state.topCardIndex >= state.students.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              "You've seen everyone!",
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    final remaining = state.students.length - state.topCardIndex;
    final visibleCount = remaining.clamp(0, 3);
    final visibleIndexes = List<int>.generate(
      visibleCount,
      (i) => state.topCardIndex + i,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 25),
      child: Stack(
        children: [
          for (final index in visibleIndexes.reversed)
            Positioned.fill(
              child: index == state.topCardIndex
                  ? _DraggableCard(
                      key: ValueKey(state.students[index].id),
                      enabled: true,
                      swipeNotifier: _swipeProgressNotifier,
                      onSwipedLeft: () => ref
                          .read(discoverConnectProvider.notifier)
                          .swipeLeft(state.students[index]),
                      onSwipedRight: () => ref
                          .read(discoverConnectProvider.notifier)
                          .swipeRight(state.students[index]),
                      child: _buildSwipeCard(
                        state.students[index],
                        interactive: true,
                      ),
                    )
                  : ValueListenableBuilder<double>(
                      valueListenable: _swipeProgressNotifier,
                      builder: (context, dragProgress, _) {
                        final depth = index - state.topCardIndex;
                        final scale =
                            (1.0 - (depth * 0.04)) + (0.04 * dragProgress);
                        final slideRatio =
                            -0.018 * depth + (0.018 * dragProgress);

                        return FractionalTranslation(
                          translation: Offset(0, slideRatio),
                          child: Transform.scale(
                            scale: scale,
                            child: _DraggableCard(
                              key: ValueKey(state.students[index].id),
                              enabled: false,
                              onSwipedLeft: () {},
                              onSwipedRight: () {},
                              child: _buildSwipeCard(
                                state.students[index],
                                interactive: false,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  // ---------------- SWIPE CARD ----------------
  Widget _buildSwipeCard(User student, {required bool interactive}) {
    return GestureDetector(
      onTap: interactive
          ? () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(userId: student.id),
                ),
              );
            }
          : null,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(child: _buildCardBackground(student)),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, left: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${student.department} • Batch ${student.batch}",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ],
                    ),
                  ),
                ),
                if (student.interests.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 10,
                      right: 10,
                      bottom: 16,
                    ),
                    child: Container(
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(
                              'Interests',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Divider(height: 1, color: Colors.grey.shade300),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: student.interests
                                  .take(5) // Safety check, Although should never be more than 5
                                  .map(
                                    (Interest interest) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFE0E6ED),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (interest.emoji.isNotEmpty) ...[
                                            Text(
                                              interest.emoji,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          Text(
                                            interest.name,
                                            style: const TextStyle(
                                              color: Color(0xFF334155),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBackground(User student) {
    if (student.picture != null && student.picture!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            student.picture!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildDefaultBackground(),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return _buildDefaultBackground();
  }

  Widget _buildDefaultBackground() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.grey.shade700,
      ),
      child: const Center(
        child: Icon(Icons.person, size: 80, color: Colors.white),
      ),
    );
  }

  // ---------------- ERROR STATE ----------------
  Widget _buildErrorState() {
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
                onPressed: () => ref
                    .read(discoverConnectProvider.notifier)
                    .refreshDiscoverUsers(forceRefresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
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
}

// ================================================================
// _DraggableCard — zero external dependencies.
// Uses only GestureDetector + Transform + internal
// AnimationControllers that we fully control, so it never fires
// during Flutter Web's frame pipeline.
// ================================================================
class _DraggableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipedLeft;
  final VoidCallback onSwipedRight;
  final bool enabled;
  final ValueNotifier<double>? swipeNotifier;

  const _DraggableCard({
    super.key,
    required this.child,
    required this.onSwipedLeft,
    required this.onSwipedRight,
    required this.enabled,
    this.swipeNotifier,
  });

  @override
  State<_DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<_DraggableCard>
    with TickerProviderStateMixin {
  Offset _offset = Offset.zero;
  late AnimationController _controller;
  late Animation<Offset> _animation;
  bool _animating = false;

  static const double _swipeThreshold = 100.0;

  void _setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _updateOffset(Offset newOffset) {
    _setStateIfMounted(() => _offset = newOffset);
    if (widget.enabled && widget.swipeNotifier != null) {
      if (!mounted) return;
      double screenWidth = MediaQuery.of(context).size.width;
      // Progress hits 1.0 when dragged halfway off the screen
      double progress = (newOffset.dx.abs() / (screenWidth * 0.6)).clamp(
        0.0,
        1.0,
      );
      widget.swipeNotifier!.value = progress;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation = AlwaysStoppedAnimation(Offset.zero);
    _controller.addListener(() {
      _updateOffset(_animation.value);
    });
  }

  @override
  void didUpdateWidget(covariant _DraggableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _controller.stop();
      _animating = false;
      _offset = Offset.zero;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!widget.enabled) return;
    if (_animating) return;
    _updateOffset(_offset + d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    if (!widget.enabled) return;
    if (_animating) return;
    if (_offset.dx.abs() >= _swipeThreshold) {
      _animating = true;
      final dir = _offset.dx > 0 ? 1.0 : -1.0;
      double screenWidth = MediaQuery.of(context).size.width;
      _animation = Tween<Offset>(
        begin: _offset,
        end: Offset(dir * screenWidth * 1.5, _offset.dy),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
      _controller.forward(from: 0).then((_) {
        if (dir > 0) {
          widget.onSwipedRight();
        } else {
          widget.onSwipedLeft();
        }
        if (mounted) {
          _offset = Offset.zero;
          _animating = false;
          if (widget.swipeNotifier != null) {
            widget.swipeNotifier!.value = 0.0;
          }
        }
      });
    } else {
      // Snap back
      _animation = Tween<Offset>(begin: _offset, end: Offset.zero).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutQuint),
      );
      _controller.duration = const Duration(milliseconds: 300);
      _controller.forward(from: 0).then((_) {
        _controller.duration = const Duration(milliseconds: 250);
        _animating = false;
      });
    }
  }

  Widget _buildSwipeCue({required IconData icon, required Color color}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 2),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_offset.dx.abs() / (_swipeThreshold * 1.2)).clamp(
      0.0,
      1.0,
    );
    final rightOpacity = _offset.dx > 0 ? progress : 0.0;
    final leftOpacity = _offset.dx < 0 ? progress : 0.0;

    final content = Transform.translate(
      offset: _offset,
      child: Transform.rotate(
        angle: widget.enabled ? _offset.dx / 1200 : 0,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (widget.enabled)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Opacity(
                      opacity: leftOpacity,
                      child: _buildSwipeCue(
                        icon: Icons.close_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.enabled)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Opacity(
                      opacity: rightOpacity,
                      child: _buildSwipeCue(
                        icon: Icons.check_rounded,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (!widget.enabled) {
      return content;
    }

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: content,
    );
  }
}
