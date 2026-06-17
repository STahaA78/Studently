import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/services/analytics_service.dart';
import 'package:studently/logger.dart';
import 'package:studently/models/user.dart';
import 'package:studently/providers/auth_provider.dart';
import 'package:studently/repositories/discover.dart';
import 'package:studently/services/storage.dart';
import 'package:studently/storage/discover_storage.dart';

final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  return DiscoverRepository();
});

final discoverConnectProvider = NotifierProvider.autoDispose<DiscoverConnectNotifier, DiscoverConnectState>(
      DiscoverConnectNotifier.new,
    );

final discoverRequestsProvider = NotifierProvider.autoDispose<
      DiscoverRequestsNotifier,
      DiscoverRequestsState
    >(DiscoverRequestsNotifier.new);

// ── DiscoverConnectState ───────────────────────────────────────────────────

class DiscoverConnectState {
  final List<User> baseStudents;
  final List<User> students;
  final Map<String, String> connectionStatus;
  final int pendingRequestsCount;
  final bool isSearchFocused;
  final List<String> recentSearches;
  final String? selectedDepartmentName;
  final String? selectedBatchYear;
  final String? selectedCampusName;
  final String? selectedCampusCode;
  final int topCardIndex;
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final String searchQuery;
  final Set<String> swipedLeftIds;

  const DiscoverConnectState({
    required this.baseStudents,
    required this.students,
    required this.connectionStatus,
    required this.pendingRequestsCount,
    required this.isSearchFocused,
    required this.recentSearches,
    required this.selectedDepartmentName,
    required this.selectedBatchYear,
    required this.selectedCampusName,
    required this.selectedCampusCode,
    required this.topCardIndex,
    required this.isLoading,
    required this.isRefreshing,
    required this.errorMessage,
    required this.searchQuery,
    required this.swipedLeftIds,
  });

  factory DiscoverConnectState.initial() {
    return const DiscoverConnectState(
      baseStudents: [],
      students: [],
      connectionStatus: {},
      pendingRequestsCount: 0,
      isSearchFocused: false,
      recentSearches: [],
      selectedDepartmentName: null,
      selectedBatchYear: null,
      selectedCampusName: null,
      selectedCampusCode: null,
      topCardIndex: 0,
      isLoading: true,
      isRefreshing: false,
      errorMessage: null,
      searchQuery: '',
      swipedLeftIds: {},
    );
  }

  DiscoverConnectState copyWith({
    List<User>? baseStudents,
    List<User>? students,
    Map<String, String>? connectionStatus,
    int? pendingRequestsCount,
    bool? isSearchFocused,
    List<String>? recentSearches,
    String? selectedDepartmentName,
    String? selectedBatchYear,
    String? selectedCampusName,
    String? selectedCampusCode,
    int? topCardIndex,
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
    String? searchQuery,
    Set<String>? swipedLeftIds,
  }) {
    return DiscoverConnectState(
      baseStudents: baseStudents ?? this.baseStudents,
      students: students ?? this.students,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      pendingRequestsCount: pendingRequestsCount ?? this.pendingRequestsCount,
      isSearchFocused: isSearchFocused ?? this.isSearchFocused,
      recentSearches: recentSearches ?? this.recentSearches,
      selectedDepartmentName:
          selectedDepartmentName ?? this.selectedDepartmentName,
      selectedBatchYear: selectedBatchYear ?? this.selectedBatchYear,
      selectedCampusName: selectedCampusName ?? this.selectedCampusName,
      selectedCampusCode: selectedCampusCode ?? this.selectedCampusCode,
      topCardIndex: topCardIndex ?? this.topCardIndex,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      swipedLeftIds: swipedLeftIds ?? this.swipedLeftIds,
    );
  }
}

// ── DiscoverConnectNotifier ────────────────────────────────────────────────

class DiscoverConnectNotifier extends Notifier<DiscoverConnectState> {
  late DiscoverRepository _repository;
  late DiscoverStorage _storage;
  Timer? _searchDebounceTimer;
  Timer? _interactionFlushTimer;
  bool _hasInitialized = false;
  bool _isFetchingNext = false;
  bool _isFetchingFiltered = false;
  static const int _pageSize = 15;
  static const int _interactionFlushThreshold = 5;
  static const int _cardPrefetchThreshold = 3;
  static const Duration _interactionFlushDelay = Duration(minutes: 1);

  static const int _cacheDurationMs = 300000;

  Future<void> init() async {
    if (_hasInitialized) return;
    _hasInitialized = true;
    _hydrateFromCache();
    await _refreshIfStale();
    await refreshPendingRequests();
  }

  @override
  DiscoverConnectState build() {
    _repository = ref.read(discoverRepositoryProvider);
    _storage = StorageService().discoverStorage;
    ref.onDispose(() {
      _searchDebounceTimer?.cancel();
      _interactionFlushTimer?.cancel();
      unawaited(flushPendingInteractions(forceRefresh: true));
    });

    // Use microtask to ensure repository/storage are used after build
    Future.microtask(() {
      _hydrateFromCache();
      init();
    });

    return DiscoverConnectState.initial();
  }

  void _hydrateFromCache() {
    final cachedUsers = _storage.getCachedDiscoverUsers();
    final userCampus = ref.read(authProvider).value?.campus;
    final selectedCampusCode = state.selectedCampusCode ?? userCampus?.code;
    final selectedCampusName = state.selectedCampusName ?? userCampus?.name;
    final campusFiltered = _applyFilters(
      cachedUsers,
      departmentName: state.selectedDepartmentName,
      batchYear: state.selectedBatchYear,
      campusCode: selectedCampusCode,
    );

    state = state.copyWith(
      baseStudents: cachedUsers,
      students: campusFiltered,
      pendingRequestsCount: _storage.getCachedPendingRequests().length,
      isLoading: cachedUsers.isEmpty,
      errorMessage: null,
      selectedCampusCode: selectedCampusCode,
      selectedCampusName: selectedCampusName,
      topCardIndex: 0,
    );
  }

  Future<void> _refreshIfStale() async {
    final lastFetch = _storage.getDiscoverLastFetchTime();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (state.baseStudents.isEmpty ||
        lastFetch == null ||
        (now - lastFetch) > _cacheDurationMs) {
      await refreshDiscoverUsers(
        forceRefresh: true,
        replaceExisting: true,
      );
    }
  }

  List<User> _applyFilters(
    List<User> users, {
    required String? departmentName,
    required String? batchYear,
    required String? campusCode,
  }) {
    var filtered = users;
    if (departmentName != null) {
      filtered = filtered
          .where((user) => user.department?.name == departmentName)
          .toList();
    }
    if (batchYear != null) {
      filtered = filtered
          .where((user) => user.batch?.toString() == batchYear)
          .toList();
    }
    if (campusCode != null) {
      filtered = filtered
          .where((user) => user.campus?.code == campusCode)
          .toList();
    }
    return filtered;
  }

  bool get _hasActiveFilters =>
      state.selectedDepartmentName != null ||
      state.selectedBatchYear != null ||
      state.selectedCampusCode != null;

  bool get _isFilteredView => _hasActiveFilters;

  Future<void> refreshDiscoverUsers({
    bool forceRefresh = false,
    bool replaceExisting = false,
    bool skipFlush = false,
  }) async {
    if (state.isRefreshing) return;

    final lastFetch = _storage.getDiscoverLastFetchTime();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!forceRefresh &&
        lastFetch != null &&
        (now - lastFetch) <= _cacheDurationMs &&
        state.baseStudents.isNotEmpty) {
      return;
    }

    state = state.copyWith(
      isRefreshing: true,
      isLoading: state.baseStudents.isEmpty,
      errorMessage: null,
    );

    try {
      if (forceRefresh && !skipFlush) {
        await flushPendingInteractions(forceRefresh: true);
      }

      final users = await _repository.discoverUsers(
        limit: _pageSize,
        campusCode: state.selectedCampusCode,
        departmentName: state.selectedDepartmentName,
        batchYear: state.selectedBatchYear,
        forceRefresh: forceRefresh,
      );
      final statuses = await _repository.fetchConnectionStatuses(
        users.map((user) => user.id).toList(),
      );
      final validUsers = users
          .where(
            (user) =>
                statuses.containsKey(user.id) && statuses[user.id] == 'none',
          )
          .toList();
      final newBase = replaceExisting
          ? validUsers
          : (() {
              final combined = [...state.baseStudents, ...validUsers];
              final Map<String, User> uniq = {};
              for (var u in combined) {
                uniq[u.id] = u;
              }
              return uniq.values.toList();
            })();

      _storage.saveDiscoverUsers(newBase);
      _storage.setDiscoverLastFetchTime(now);

      final filtered = _applyFilters(
        newBase,
        departmentName: state.selectedDepartmentName,
        batchYear: state.selectedBatchYear,
        campusCode: state.selectedCampusCode,
      );

      state = state.copyWith(
        baseStudents: replaceExisting ? users : newBase,
        students: state.searchQuery.isEmpty ? filtered : state.students,
        connectionStatus: statuses,
        topCardIndex: replaceExisting ? 0 : state.topCardIndex,
        isLoading: false,
        isRefreshing: false,
        errorMessage: null,
      );
    } catch (e) {
      logger.e('[DiscoverConnectNotifier] refreshDiscoverUsers failed: $e');
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> refreshPendingRequests({bool forceRefresh = false}) async {
    final lastFetch = _storage.getPendingLastFetchTime();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!forceRefresh &&
        lastFetch != null &&
        (now - lastFetch) <= _cacheDurationMs) {
      state = state.copyWith(
        pendingRequestsCount: _storage.getCachedPendingRequests().length,
      );
      return;
    }

    try {
      final requests = await _repository.fetchPendingRequests();
      _storage.savePendingRequests(requests);
      _storage.setPendingLastFetchTime(now);
      state = state.copyWith(pendingRequestsCount: requests.length);
    } catch (e) {
      logger.e('[DiscoverConnectNotifier] refreshPendingRequests failed: $e');
    }
  }

  void setSearchFocused(bool isFocused) {
    state = state.copyWith(isSearchFocused: isFocused);
  }

  void onSearchChanged(String query) {
    final trimmed = query.trim();
    _searchDebounceTimer?.cancel();

    if (trimmed.isEmpty) {
      clearSearch();
      return;
    }

    state = state.copyWith(isSearchFocused: true);

    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      runSearch(trimmed);
    });
  }

  Future<void> runSearch(String query) async {
    state = state.copyWith(
      isSearchFocused: true,
      searchQuery: query,
      isLoading: state.students.isEmpty,
      errorMessage: null,
      topCardIndex: 0,
    );

    final updatedRecent = List<String>.from(state.recentSearches);
    if (!updatedRecent.contains(query)) {
      updatedRecent.insert(0, query);
      if (updatedRecent.length > 5) updatedRecent.removeLast();
    }
    state = state.copyWith(recentSearches: updatedRecent);

    try {
      final results = await _repository.searchUsers(query);
      state = state.copyWith(students: results, isLoading: false);
    } catch (e) {
      logger.e('[DiscoverConnectNotifier] runSearch failed: $e');
      state = state.copyWith(students: [], isLoading: false);
    }
  }

  void clearSearch() {
    _searchDebounceTimer?.cancel();
    final filtered = _applyFilters(
      state.baseStudents,
      departmentName: state.selectedDepartmentName,
      batchYear: state.selectedBatchYear,
      campusCode: state.selectedCampusCode,
    );

    state = state.copyWith(
      searchQuery: '',
      isSearchFocused: false,
      students: filtered,
      topCardIndex: 0,
      errorMessage: null,
    );

    if (filtered.isEmpty) refreshDiscoverUsers();
  }

  void clearRecentSearches() {
    _storage.clearRecentSearches();
    state = state.copyWith(recentSearches: []);
  }

  void removeRecentSearch(String query) {
    final updated = List<String>.from(state.recentSearches)..remove(query);
    _storage.saveRecentSearches(updated);
    state = state.copyWith(recentSearches: updated);
  }

  void applyFilters({
    String? departmentName,
    String? batchYear,
    String? campusName,
    String? campusCode,
  }) {
    final nextState = state.copyWith(
      selectedDepartmentName: departmentName,
      selectedBatchYear: batchYear,
      selectedCampusName: campusName,
      selectedCampusCode: campusCode,
      topCardIndex: 0,
    );

    final filtered = _applyFilters(
      nextState.baseStudents,
      departmentName: departmentName,
      batchYear: batchYear,
      campusCode: campusCode,
    );
    final shouldFetchRemote = nextState.searchQuery.isEmpty &&
        filtered.isEmpty &&
        (departmentName != null || batchYear != null || campusCode != null);
    final shouldPrefetchRemote = nextState.searchQuery.isEmpty &&
        filtered.isNotEmpty &&
        filtered.length <= 3;

    state = nextState.copyWith(
      students: nextState.searchQuery.isEmpty ? filtered : nextState.students,
    );

    unawaited(
      AnalyticsService.logEvent(
        AnalyticsEvents.discoverFilterChanged,
        parameters: {
          'action':
              departmentName == null && batchYear == null && campusCode == null
              ? 'reset'
              : 'apply',
          'department_set': departmentName != null,
          'batch_set': batchYear != null,
          'campus_set': campusCode != null,
          'active_filter_count': [
            departmentName,
            batchYear,
            campusCode,
          ].where((value) => value != null).length,
          'search_active': state.searchQuery.isNotEmpty,
          'result_count': filtered.length,
        },
      ),
    );

    if (shouldFetchRemote) {
      unawaited(
        refreshFilteredDiscoverUsers(
          departmentName: departmentName,
          batchYear: batchYear,
          campusCode: campusCode,
          append: false,
          showLoading: true,
        ),
      );
    } else if (shouldPrefetchRemote) {
      unawaited(
        refreshFilteredDiscoverUsers(
          departmentName: departmentName,
          batchYear: batchYear,
          campusCode: campusCode,
          append: true,
          showLoading: false,
        ),
      );
    }
  }

  void resetFilters() {
    applyFilters(
      departmentName: null,
      batchYear: null,
      campusName: null,
      campusCode: null,
    );
  }

  Future<void> refreshFilteredDiscoverUsers({
    String? departmentName,
    String? batchYear,
    String? campusCode,
    bool append = false,
    bool showLoading = true,
  }) async {
    if (_isFetchingFiltered) return;
    _isFetchingFiltered = true;

    if (showLoading) {
      state = state.copyWith(
        isRefreshing: true,
        isLoading: false,
        errorMessage: null,
        topCardIndex: 0,
      );
    }

    try {
      await _flushPendingInteractionsIfNeeded(forceRefresh: true);

      final users = await _repository.discoverUsers(
        limit: _pageSize,
        campusCode: campusCode ?? state.selectedCampusCode,
        departmentName: departmentName ?? state.selectedDepartmentName,
        batchYear: batchYear ?? state.selectedBatchYear,
        forceRefresh: true,
      );
      final statuses = await _repository.fetchConnectionStatuses(
        users.map((user) => user.id).toList(),
      );
      final validUsers = users
          .where(
            (user) =>
                statuses.containsKey(user.id) && statuses[user.id] == 'none',
          )
          .toList();

      final nextStudents = append
          ? _mergeUniqueStudents(state.students, validUsers)
          : validUsers;
      final nextStatuses = Map<String, String>.from(state.connectionStatus)
        ..addAll(statuses);

      state = state.copyWith(
        students: nextStudents,
        connectionStatus: nextStatuses,
        isLoading: false,
        isRefreshing: false,
        errorMessage: null,
        topCardIndex: append ? state.topCardIndex : 0,
      );
    } catch (e) {
      logger.e('[DiscoverConnectNotifier] refreshFilteredDiscoverUsers failed: $e');
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: e.toString(),
      );
    } finally {
      _isFetchingFiltered = false;
    }
  }

  void swipeLeft(User student) {
    unawaited(
      AnalyticsService.logEvent(
        AnalyticsEvents.discoverCardSwipe,
        parameters: {
          'direction': 'left',
          'result': 'dismissed',
          'has_thumbnail': (student.thumbnail ?? '').isNotEmpty,
          'department_code': student.department?.code,
          'campus_code': student.campus?.code,
          'batch_year': student.batch,
        },
      ),
    );
    _queueInteraction(student.id, 'left');
    unawaited(advanceCard());
  }

  void swipeRight(User student) {
    unawaited(
      AnalyticsService.logEvent(
        AnalyticsEvents.discoverCardSwipe,
        parameters: {
          'direction': 'right',
          'result': 'connection_request',
          'has_thumbnail': (student.thumbnail ?? '').isNotEmpty,
          'department_code': student.department?.code,
          'campus_code': student.campus?.code,
          'batch_year': student.batch,
        },
      ),
    );
    _queueInteraction(student.id, 'right');
    final updatedStatuses = Map<String, String>.from(state.connectionStatus)
      ..[student.id] = 'outgoing_request';
    state = state.copyWith(connectionStatus: updatedStatuses);
    unawaited(advanceCard());

    Future(() async {
      try {
        await _repository.sendConnectionRequest(student.id);
      } catch (e) {
        logger.e('[DiscoverConnectNotifier] swipeRight failed: $e');
      }
    });
  }

  Future<void> cancelConnectionRequest(String targetId) async {
    try {
      await _repository.cancelConnectionRequest(targetId);
      final updatedStatuses = Map<String, String>.from(state.connectionStatus)
        ..[targetId] = 'none';
      state = state.copyWith(connectionStatus: updatedStatuses);
    } catch (e) {
      logger.e('[DiscoverConnectNotifier] cancelConnectionRequest failed: $e');
    }
  }

  Future<void> advanceCard() async {
    if (state.topCardIndex < state.students.length) {
      state = state.copyWith(topCardIndex: state.topCardIndex + 1);
    }
    final queueLength = _storage.getPendingInteractions().length;
    final shouldPrefetchMore =
        !_isFilteredView &&
        !_isFetchingNext &&
        _shouldPrefetchMore(state.students.length);
    final shouldPrefetchFiltered =
        _isFilteredView &&
        !_isFetchingNext &&
        _shouldPrefetchFiltered(state.students.length);

    if (queueLength > 0 && (shouldPrefetchMore || shouldPrefetchFiltered)) {
      await flushPendingInteractions(forceRefresh: true);
    } else if (queueLength >= _interactionFlushThreshold) {
      await flushPendingInteractions();
    }

    if (shouldPrefetchMore) {
      await _fetchNextPage();
    }
    if (shouldPrefetchFiltered) {
      await refreshFilteredDiscoverUsers(
        departmentName: state.selectedDepartmentName,
        batchYear: state.selectedBatchYear,
        campusCode: state.selectedCampusCode,
        append: true,
        showLoading: false,
      );
    }
  }

  Future<void> _fetchNextPage() async {
    _isFetchingNext = true;
    try {
      await refreshDiscoverUsers(
        forceRefresh: true,
        replaceExisting: false,
        skipFlush: true,
      );
    } catch (e) {
      logger.e('[DiscoverConnectNotifier] _fetchNextPage failed: $e');
    } finally {
      _isFetchingNext = false;
    }
  }

  bool _shouldPrefetchMore(int totalCount) {
    return state.topCardIndex >= (totalCount - _cardPrefetchThreshold);
  }

  bool _shouldPrefetchFiltered(int totalCount) {
    if (!_isFilteredView) return false;
    final remaining = totalCount - state.topCardIndex;
    return remaining <= _cardPrefetchThreshold && totalCount > 0;
  }

  List<User> _mergeUniqueStudents(List<User> current, List<User> incoming) {
    final merged = <String, User>{};
    for (final user in current) {
      merged[user.id] = user;
    }
    for (final user in incoming) {
      merged[user.id] = user;
    }
    return merged.values.toList();
  }

  void _queueInteraction(String targetId, String direction) {
    final interaction = <String, dynamic>{
      'target_id': targetId,
      'direction': direction,
      'interacted_at': DateTime.now().toIso8601String(),
    };
    _storage.addPendingInteraction(interaction);
    _interactionFlushTimer?.cancel();
    _interactionFlushTimer = Timer(_interactionFlushDelay, () {
      unawaited(flushPendingInteractions(forceRefresh: true));
    });
  }

  Future<void> _flushPendingInteractionsIfNeeded({
    bool forceRefresh = false,
  }) async {
    if (_storage.getPendingInteractions().isEmpty) {
      _interactionFlushTimer?.cancel();
      return;
    }
    await flushPendingInteractions(forceRefresh: forceRefresh);
  }

  Future<void> flushPendingInteractions({bool forceRefresh = false}) async {
    _interactionFlushTimer?.cancel();
    final queue = _storage.getPendingInteractions();
    if (queue.isEmpty) return;

    try {
      await _repository.sendDiscoverInteractions(
        queue,
        forceRefresh: forceRefresh,
      );
      _storage.clearPendingInteractions();
    } catch (e) {
      logger.e('[DiscoverConnectNotifier] flushPendingInteractions failed: $e');
    }
  }
}

// ── DiscoverRequestsState ──────────────────────────────────────────────────

class DiscoverRequestsState {
  final List<User> requests;
  final bool isLoading;
  final bool hasLoadedRequests;
  final bool didChangeRequests;
  final String? errorMessage;
  final Set<String> inFlightRequestIds;

  const DiscoverRequestsState({
    required this.requests,
    required this.isLoading,
    required this.hasLoadedRequests,
    required this.didChangeRequests,
    required this.errorMessage,
    required this.inFlightRequestIds,
  });

  factory DiscoverRequestsState.initial() {
    return const DiscoverRequestsState(
      requests: [],
      isLoading: true,
      hasLoadedRequests: false,
      didChangeRequests: false,
      errorMessage: null,
      inFlightRequestIds: {},
    );
  }

  DiscoverRequestsState copyWith({
    List<User>? requests,
    bool? isLoading,
    bool? hasLoadedRequests,
    bool? didChangeRequests,
    String? errorMessage,
    Set<String>? inFlightRequestIds,
  }) {
    return DiscoverRequestsState(
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      hasLoadedRequests: hasLoadedRequests ?? this.hasLoadedRequests,
      didChangeRequests: didChangeRequests ?? this.didChangeRequests,
      errorMessage: errorMessage,
      inFlightRequestIds: inFlightRequestIds ?? this.inFlightRequestIds,
    );
  }
}

// ── DiscoverRequestsNotifier ───────────────────────────────────────────────

class DiscoverRequestsNotifier extends Notifier<DiscoverRequestsState> {
  late DiscoverRepository _repository;
  late DiscoverStorage _storage;

  @override
  DiscoverRequestsState build() {
    _repository = ref.read(discoverRepositoryProvider);
    _storage = StorageService().discoverStorage;

    Future.microtask(() {
      _hydrateFromCache();
      unawaited(refreshRequests(showLoading: false));
    });

    return DiscoverRequestsState.initial();
  }

  void _hydrateFromCache() {
    final cachedRequests = _storage.getCachedPendingRequests();
    state = state.copyWith(
      requests: cachedRequests,
      hasLoadedRequests: cachedRequests.isNotEmpty,
      isLoading: cachedRequests.isEmpty,
      errorMessage: null,
    );
  }

  Future<void> refreshRequests({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      final freshRequests = await _repository.fetchPendingRequests();
      _storage.savePendingRequests(freshRequests);
      _storage.setPendingLastFetchTime(DateTime.now().millisecondsSinceEpoch);
      state = state.copyWith(
        requests: freshRequests,
        hasLoadedRequests: true,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      logger.e('[DiscoverRequestsNotifier] refreshRequests failed: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> respondRequest(String requesterId, String action) async {
    if (state.inFlightRequestIds.contains(requesterId)) return false;

    User? removedUser;
    final updatedInFlight = Set<String>.from(state.inFlightRequestIds)
      ..add(requesterId);
    final updatedRequests = List<User>.from(state.requests);
    final index = updatedRequests.indexWhere((u) => u.id == requesterId);
    if (index != -1) removedUser = updatedRequests.removeAt(index);

    state = state.copyWith(
      inFlightRequestIds: updatedInFlight,
      requests: updatedRequests,
      didChangeRequests: true,
    );
    _storage.savePendingRequests(updatedRequests);

    try {
      await ref
          .read(authProvider.notifier)
          .respondToFriendRequest(requesterId, action);

      final clearedInFlight = Set<String>.from(state.inFlightRequestIds)
        ..remove(requesterId);
      state = state.copyWith(inFlightRequestIds: clearedInFlight);
      return true;
    } catch (e) {
      logger.e('[DiscoverRequestsNotifier] respondRequest failed: $e');

      final clearedInFlight = Set<String>.from(state.inFlightRequestIds)
        ..remove(requesterId);
      final rollbackRequests = List<User>.from(state.requests);
      if (removedUser != null &&
          !rollbackRequests.any((u) => u.id == removedUser!.id)) {
        rollbackRequests.insert(0, removedUser);
      }

      state = state.copyWith(
        inFlightRequestIds: clearedInFlight,
        requests: rollbackRequests,
        errorMessage: e.toString(),
      );
      _storage.savePendingRequests(rollbackRequests);
      await refreshRequests(showLoading: false);
      return false;
    }
  }

  void markChanged() {
    if (!state.didChangeRequests) {
      state = state.copyWith(didChangeRequests: true);
    }
  }
}
