import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:studently/app_style.dart';
import 'package:studently/models/backend_config.dart';
import 'package:studently/models/teachers.dart';
import 'package:studently/providers/backend_config_provider.dart';
import 'package:studently/providers/auth_provider.dart';
import 'package:studently/providers/teachers_provider.dart';
import 'package:studently/screens/teacher_add_page.dart';
import 'package:studently/screens/teacher_reviews_page.dart';
import 'package:studently/utils/web_utils.dart' as web_utils;
import 'package:studently/widgets/custom_nav_bar.dart';

class TeachersPage extends ConsumerStatefulWidget {
  const TeachersPage({super.key});

  @override
  ConsumerState<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends ConsumerState<TeachersPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Color blue = AppStyle.primaryBlue;

  List<Teacher> allTeachers = [];
  List<Teacher> filteredTeachers = [];
  bool isInitialized = false;
  String? _activeLetter;
  String? _selectedDepartmentFilterCode;
  String? _selectedDepartmentFilterName;
  String? _selectedCampusFilterCode;
  String? _selectedCampusFilterName;
  final GlobalKey _alphabetBarKey = GlobalKey();
  final GlobalKey _firstCardKey = GlobalKey();
  final GlobalKey _headerKey = GlobalKey();
  double? _measuredCardHeight;
  double? _measuredHeaderHeight;

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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterTeachers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _filterTeachers() {
    setState(() {
      filteredTeachers = _getFilteredTeachers();
      _buildLetterIndexMap();
    });
  }

  List<Teacher> _getFilteredTeachers() {
    final query = _searchController.text.toLowerCase();
    return allTeachers.where((teacher) {
      final displayName = _displayName(teacher).toLowerCase();
      final nameMatch = displayName.contains(query) ||
          teacher.name.toLowerCase().contains(query) ||
          teacher.title.toLowerCase().contains(query);
      final departmentMatch = teacher.department.name.toLowerCase().contains(
            query,
          ) ||
          teacher.department.code.toLowerCase().contains(query);
      final filterMatch = _selectedDepartmentFilterCode == null ||
          teacher.department.code == _selectedDepartmentFilterCode;
      final campusMatch = _selectedCampusFilterCode == null ||
          teacher.campus.code == _selectedCampusFilterCode;
      return (nameMatch || departmentMatch) && filterMatch && campusMatch;
    }).toList();
  }

  void _applyDepartmentFilter(String? departmentCode) {
    final departments = ref
        .read(backendConfigProvider)
        .maybeWhen(
          data: (config) => config.departments,
          orElse: () => const <Department>[],
        );
    final selectedDepartment =
        departments.where((dept) => dept.code == departmentCode).toList();
    _selectedDepartmentFilterCode = departmentCode;
    _selectedDepartmentFilterName =
        selectedDepartment.isNotEmpty ? selectedDepartment.first.name : null;
    _filterTeachers();
  }

  void _applyCampusFilter(String? campusCode) {
    final campuses = ref
        .read(backendConfigProvider)
        .maybeWhen(
          data: (config) => config.campuses,
          orElse: () => const <Campus>[],
        );
    final selectedCampus =
        campuses.where((campus) => campus.code == campusCode).toList();
    _selectedCampusFilterCode = campusCode;
    _selectedCampusFilterName =
        selectedCampus.isNotEmpty ? selectedCampus.first.name : null;
    _filterTeachers();
  }

  void _showFilterPanel() {
    final configAsync = ref.read(backendConfigProvider);
    String? tempDepartmentCode = _selectedDepartmentFilterCode;
    String? tempCampusCode =
        _selectedCampusFilterCode ?? ref.read(authProvider).value?.campus?.code;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: configAsync.when(
              loading: () => const SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Error loading filters: $error')),
              ),
              data: (config) {
                final resolvedCampusCode = config.campuses.any(
                  (campus) => campus.code == tempCampusCode,
                )
                    ? tempCampusCode
                    : null;
                return StatefulBuilder(
                  builder: (context, setSheetState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Filter',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(sheetContext),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Campus',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 50,
                          decoration: AppStyle.dropdownContainerDecoration(),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              key: ValueKey(tempCampusCode),
                              value: resolvedCampusCode,
                              hint: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Select Campus'),
                              ),
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              icon: const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.grey,
                                ),
                              ),
                              items: config.campuses
                                  .map(
                                    (campus) => DropdownMenuItem(
                                      value: campus.code,
                                      child: Text(campus.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setSheetState(() {
                                  tempCampusCode = value;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              menuMaxHeight: 220,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Department',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 50,
                          decoration: AppStyle.dropdownContainerDecoration(),
                          child: DropdownButtonFormField<String>(
                            initialValue: tempDepartmentCode,
                            hint: const Text('Select Department'),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                            decoration: AppStyle.dropdownInputDecoration(
                              hintText: 'Select Department',
                            ),
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey,
                            ),
                            items: config.departments
                                .map(
                                  (dept) => DropdownMenuItem(
                                    value: dept.code,
                                    child: Text(dept.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setSheetState(() {
                                tempDepartmentCode = value;
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            menuMaxHeight: 220,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    _applyDepartmentFilter(null);
                                    _applyCampusFilter(null);
                                  },
                                  child: const Text('Reset'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    _applyDepartmentFilter(tempDepartmentCode);
                                    _applyCampusFilter(tempCampusCode);
                                  },
                                  child: const Text('Apply'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _buildLetterIndexMap() {
    _letterIndexMap = {};
    for (int i = 0; i < filteredTeachers.length; i++) {
      final name = filteredTeachers[i].name.trim();
      if (name.isEmpty) continue;
      final letter = name[0].toUpperCase();
      _letterIndexMap.putIfAbsent(letter, () => i);
    }
  }

  String _displayName(Teacher teacher) {
    return '${teacher.title} ${teacher.name}'.trim();
  }

  void _measureHeights() {
    if (_measuredCardHeight == null) {
      final box =
          _firstCardKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
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
    final cardH = _measuredCardHeight ?? 147.0;
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
        _scrollToLetter(letter);
      }
    }
  }

  Future<void> _openAddTeacher() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTeacherPage()),
    );
    if (!mounted) return;
    await ref.read(teachersProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(teachersProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(teachersProvider.notifier).refresh(),
          child: teachersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _buildErrorState(),
            data: (state) {
              allTeachers = state.teachers;
              filteredTeachers = _getFilteredTeachers();
              _buildLetterIndexMap();
              if (!isInitialized) {
                isInitialized = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _measureHeights();
                });
              }

              return Stack(
                children: [
                  ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                    SliverAppBar(
                      backgroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      floating: true,
                      snap: true,
                      centerTitle: true,
                      title: const Text(
                        "Teachers",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: AppStyle.appBarTitleSize,
                        ),
                      ),
                      actions: [
                        if (kIsWeb && !web_utils.isStandalonePwa())
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.black),
                            onPressed: () =>
                                ref.read(teachersProvider.notifier).refresh(),
                          ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.black),
                          onPressed: _openAddTeacher,
                        ),
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, color: Colors.black),
                          onPressed: _showFilterPanel,
                          tooltip: 'Filter',
                        ),
                      ],
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(8),
                        child: const SizedBox(key: ValueKey('teachers_header_spacer')),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        key: _headerKey,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: AppStyle.searchDecoration(
                                "Search teachers...",
                              ),
                            ),
                            if (_selectedDepartmentFilterName != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.filter_alt_rounded,
                                      size: 16,
                                      color: AppStyle.primaryBlue,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _selectedDepartmentFilterName!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _applyDepartmentFilter(null),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_selectedCampusFilterName != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: AppStyle.primaryBlue,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _selectedCampusFilterName!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _applyCampusFilter(null),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (filteredTeachers.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "No Teachers Found",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  height: 48,
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _openAddTeacher,
                                    icon: const Icon(Icons.add),
                                    label: const Text("Add Teacher"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final teacher = filteredTeachers[index];
                          final isLast = index == filteredTeachers.length - 1;
                          return Column(
                            children: [
                              Padding(
                                key: index == 0 ? _firstCardKey : null,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 7,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TeacherReviewsPage(
                                          teacherId: teacher.id,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ClipOval(
                                              child: SizedBox(
                                                width: 48,
                                                height: 48,
                                                child: teacher.profile != null && teacher.profile!.isNotEmpty
                                                    ? CachedNetworkImage(
                                                        imageUrl: teacher.profile!,
                                                        fit: BoxFit.cover,
                                                        alignment: Alignment.topCenter, // <-- use top of image
                                                      )
                                                    : Container(
                                                        color: Colors.grey[200],
                                                        child: const Icon(
                                                          Icons.person_rounded,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _displayName(teacher),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 17,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    teacher.department.name,
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 13,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[100],
                                                    borderRadius:
                                                        BorderRadius.circular(999),
                                                  ),
                                                  child: Text(
                                                    teacher.rating.toStringAsFixed(1),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[100],
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                '${teacher.reviewCount} reviews',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
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
                        }, childCount: filteredTeachers.length),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
                  ),
                  if (isInitialized && filteredTeachers.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: MediaQuery.of(context).size.height * 0.25,
                      bottom: MediaQuery.of(context).size.height * 0.15,
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
                                      color: hasData
                                          ? blue
                                          : Colors.grey.shade400,
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
            },
          ),
        ),
      ),
      bottomNavigationBar: const CustomNavBar(currentIndex: 4),
    );
  }

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
                onPressed: () => ref.read(teachersProvider.notifier).refresh(),
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
}
