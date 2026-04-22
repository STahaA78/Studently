import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/models/knowledge_hub.dart';
import 'package:studently/repositories/knowledge_hub.dart';
import 'dart:typed_data';

// ==================== REPOSITORY PROVIDER ====================
/// Global singleton instance of KnowledgeHubRepository
final knowledgeHubRepositoryProvider = Provider<KnowledgeHubRepository>((ref) {
  return KnowledgeHubRepository();
});

// ==================== COURSES PROVIDERS ====================

/// Provider for fetching all available courses with automatic caching
/// - First load: Checks cache, returns if available, otherwise fetches from API
/// - Pull-to-refresh: Use ref.read(allCoursesFreshProvider.future) to force API fetch
final allCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final repository = ref.watch(knowledgeHubRepositoryProvider);
  return repository.fetchAllCourses(); // Uses default forceRefresh: false (checks cache first)
});

/// Provider to get fresh courses from API (bypasses cache)
/// Use only for pull-to-refresh scenarios
final allCoursesFreshProvider = FutureProvider<List<Course>>((ref) async {
  final repository = ref.watch(knowledgeHubRepositoryProvider);
  return repository.fetchAllCourses(forceRefresh: true); // Bypass cache, fetch fresh
});

// ==================== RESOURCES PROVIDERS ====================

/// Provider for fetching resources for a specific course with automatic caching
/// Parameters: courseId (e.g., "CS101")
/// - First load: Checks cache, returns if available, otherwise fetches from API
final resourcesByCourseProvider = FutureProvider.family<ResourceGroup, String>(
    (ref, courseId) async {
  final repository = ref.watch(knowledgeHubRepositoryProvider);
  return repository.fetchResourcesByCourse(courseId); // Uses default forceRefresh: false
});

/// Provider to get fresh resources from API for a course (bypasses cache)
/// Use only for pull-to-refresh scenarios
/// Parameters: courseId (e.g., "CS101")
final resourcesCourseFreshProvider = FutureProvider.family<ResourceGroup, String>(
    (ref, courseId) async {
  final repository = ref.watch(knowledgeHubRepositoryProvider);
  return repository.fetchResourcesByCourse(courseId, forceRefresh: true); // Bypass cache
});

/// Provider for fetching all resource groups
final allResourceGroupsProvider =
    FutureProvider<List<ResourceGroup>>((ref) async {
  final repository = ref.watch(knowledgeHubRepositoryProvider);
  return repository.fetchResourceGroups(forceRefresh: false);
});

// ==================== DOWNLOAD PROVIDERS ====================

/// Provider for downloading resource file from a direct Cloudflare URL
/// Parameters: fileUrl (direct Cloudflare R2 URL)
final downloadResourceFromUrlProvider =
    FutureProvider.family<Uint8List, String>((ref, fileUrl) async {
  final repository = ref.watch(knowledgeHubRepositoryProvider);
  return repository.downloadFromUrl(fileUrl);
});

/// Provider for getting local file path of a cached resource
/// Parameters: (courseCode, resourceId)
final resourceLocalFilePathProvider = Provider.family<String?, (String, String)>(
  (ref, params) {
    final repository = ref.watch(knowledgeHubRepositoryProvider);
    return repository.getLocalFilePath(params.$1, params.$2);
  },
);

/// Provider to save resource local path
final saveResourceLocalPathProvider = Provider.family<
    Future<void> Function(String),
    (String, String)
>((ref, params) {
  final repository = ref.watch(knowledgeHubRepositoryProvider);
  return (String localFilePath) async {
    await repository.updateResourceLocalPath(
      params.$1,
      params.$2,
      localFilePath,
    );
  };
});

// ==================== UPLOAD PROVIDER ====================

/// Provider for managing resource uploads (supports both file paths and bytes)
/// Use path for mobile/desktop, bytes for web compatibility
final resourceUploadFunctionProvider = Provider<Future<void> Function({
  required ResourceItemRequest resourceItemRequest,
  String? filePath,
  List<int>? fileBytes,
  String? filename,
})>((ref) {
  final repository = ref.watch(knowledgeHubRepositoryProvider);
  return ({
    required ResourceItemRequest resourceItemRequest,
    String? filePath,
    List<int>? fileBytes,
    String? filename,
  }) async {
    if (fileBytes != null && filename != null) {
      // Use bytes-based upload (web-compatible)
      await repository.uploadResourceFromBytes(
        resourceItemRequest: resourceItemRequest,
        fileBytes: fileBytes,
        filename: filename,
      );
    } else if (filePath != null) {
      // Use file path-based upload (native platforms)
      await repository.uploadResource(
        resourceItemRequest: resourceItemRequest,
        filePath: filePath,
      );
    } else {
      throw Exception('Either filePath or (fileBytes + filename) must be provided');
    }
  };
});

// ==================== CACHE MANAGEMENT UTILITIES ====================

/// Custom refresh function for courses - fetches fresh from API then updates cache
final refreshAllCoursesProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    // ignore: unused_result
    ref.refresh(allCoursesFreshProvider);
    // Wait for fresh data to be fetched and cached
    await ref.watch(allCoursesFreshProvider.future);
    // Invalidate main provider to pick up updated cache
    ref.invalidate(allCoursesProvider);
  };
});

/// Custom refresh function for course resources - fetches fresh from API then updates cache
/// Parameters: courseId (e.g., "CS101")
final refreshResourcesForCourseProvider = 
    Provider.family<Future<void> Function(), String>((ref, courseId) {
  return () async {
    // ignore: unused_result
    ref.refresh(resourcesCourseFreshProvider(courseId));
    // Wait for fresh data to be fetched and cached
    await ref.watch(resourcesCourseFreshProvider(courseId).future);
    // Invalidate main provider to pick up updated cache
    ref.invalidate(resourcesByCourseProvider(courseId));
  };
});

/// Helper provider for cache invalidation - use ref.invalidate(allCoursesProvider)
/// Example usage:
///   ref.invalidate(allCoursesProvider);  // Refresh courses cache
///   ref.invalidate(resourcesByCourseProvider(courseCode));  // Refresh specific course resources
/// 
/// This ensures that on next read, the providers will fetch fresh data from API
/// while still maintaining the fallback to cached data if API fails
