import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/logger.dart';
import 'package:studently/models/user.dart';
import 'package:studently/providers/auth_provider.dart';
import 'package:studently/repositories/discover.dart';
import 'package:studently/services/storage.dart';
import 'package:studently/storage/discover_storage.dart';

final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  return DiscoverRepository();
});

final discoverConnectProvider =
    NotifierProvider<DiscoverConnectNotifier, DiscoverConnectState>(DiscoverConnectNotifier.new,);

final discoverRequestsProvider =
    NotifierProvider<DiscoverRequestsNotifier, DiscoverRequestsState>(DiscoverRequestsNotifier.new,);

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
  late final DiscoverRepository _repository;
  late final DiscoverStorage _storage;
  Timer? _searchDebounceTimer;
  bool _hasInitialized = false;

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
    return DiscoverConnectState.initial();
  }

  void _hydrateFromCache() {
    final cachedUsers = _storage.getCachedDiscoverUsers();
    final swipedLeft = _storage.getSwipedLeftIds();
    final filteredCached = _filterSwipedLeft(cachedUsers, swipedLeft);
    final filtered = _applyFilters(
      filteredCached,
      departmentName: state.selectedDepartmentName,
      batchYear: state.selectedBatchYear,
    );

    state = state.copyWith(
      baseStudents: cachedUsers,
      students: filtered,
      swipedLeftIds: swipedLeft,
      pendingRequestsCount: _storage.getCachedPendingRequests().length,
      isLoading: cachedUsers.isEmpty,
      errorMessage: null,
      topCardIndex: 0,
    );
  }

  Future<void> _refreshIfStale() async {
    final lastFetch = _storage.getDiscoverLastFetchTime();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (state.baseStudents.isEmpty ||
        lastFetch == null ||
        (now - lastFetch) > _cacheDurationMs) {
      await refreshDiscoverUsers(forceRefresh: true);
    }
  }

  List<User> _applyFilters(
    List<User> users, {
    required String? departmentName,
    required String? batchYear,
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
    return filtered;
  }

  List<User> _filterSwipedLeft(List<User> users, Set<String> swipedLeftIds) {
    return users.where((user) => !swipedLeftIds.contains(user.id)).toList();
  }

  Future<void> refreshDiscoverUsers({bool forceRefresh = false}) async {
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
      final users = await _repository.discoverUsers();
      final statuses = await _repository.fetchConnectionStatuses(
        users.map((user) => user.id).toList(),
      );
      final validUsers = users
          .where(
            (user) =>
                statuses.containsKey(user.id) && statuses[user.id] == 'none',
          )
          .toList();

      _storage.saveDiscoverUsers(validUsers);
      _storage.setDiscoverLastFetchTime(now);

      final filtered = _applyFilters(
        _filterSwipedLeft(validUsers, state.swipedLeftIds),
        departmentName: state.selectedDepartmentName,
        batchYear: state.selectedBatchYear,
      );

      state = state.copyWith(
        baseStudents: validUsers,
        students: state.searchQuery.isEmpty ? filtered : state.students,
        connectionStatus: statuses,
        topCardIndex: 0,
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
      final filtered = _filterSwipedLeft(results, state.swipedLeftIds);
      state = state.copyWith(students: filtered, isLoading: false);
    } catch (e) {
      logger.e('[DiscoverConnectNotifier] runSearch failed: $e');
      state = state.copyWith(students: [], isLoading: false);
    }
  }

  void clearSearch() {
    _searchDebounceTimer?.cancel();
    final filtered = _applyFilters(
      _filterSwipedLeft(state.baseStudents, state.swipedLeftIds),
      departmentName: state.selectedDepartmentName,
      batchYear: state.selectedBatchYear,
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
    state = state.copyWith(recentSearches: []);
  }

  void removeRecentSearch(String query) {
    final updated = List<String>.from(state.recentSearches)..remove(query);
    state = state.copyWith(recentSearches: updated);
  }

  void applyFilters({String? departmentName, String? batchYear}) {
    final nextState = state.copyWith(
      selectedDepartmentName: departmentName,
      selectedBatchYear: batchYear,
      topCardIndex: 0,
    );

    final filtered = _applyFilters(
      _filterSwipedLeft(nextState.baseStudents, nextState.swipedLeftIds),
      departmentName: departmentName,
      batchYear: batchYear,
    );

    state = nextState.copyWith(
      students: nextState.searchQuery.isEmpty ? filtered : nextState.students,
    );

    refreshDiscoverUsers();
  }

  void resetFilters() {
    applyFilters(departmentName: null, batchYear: null);
  }

  void swipeLeft(User student) {
    final updated = Set<String>.from(state.swipedLeftIds)..add(student.id);
    _storage.addSwipedLeftId(student.id);
    state = state.copyWith(swipedLeftIds: updated);
    advanceCard();
  }

  Future<void> swipeRight(User student) async {
    try {
      await _repository.sendConnectionRequest(student.id);
      final updatedStatuses = Map<String, String>.from(state.connectionStatus)
        ..[student.id] = 'outgoing_request';
      state = state.copyWith(connectionStatus: updatedStatuses);
    } catch (e) {
      logger.e('[DiscoverConnectNotifier] swipeRight failed: $e');
    } finally {
      advanceCard();
    }
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

  void advanceCard() {
    if (state.topCardIndex < state.students.length) {
      state = state.copyWith(topCardIndex: state.topCardIndex + 1);
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
  late final DiscoverRepository _repository;
  late final DiscoverStorage _storage;

  @override
  DiscoverRequestsState build() {
    _repository = ref.read(discoverRepositoryProvider);
    _storage = StorageService().discoverStorage;

    _hydrateFromCache();
    refreshRequests(showLoading: false);

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
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
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