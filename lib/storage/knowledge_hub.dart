import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:studently/models/knowledge_hub.dart';
import 'package:studently/logger.dart';

/// Service for managing local storage of knowledge hub courses, resources, and downloaded PDF files
class KnowledgeHubStorage {
  static const String _coursesBoxName = 'kh_courses';
  static const String _resourcesBoxName = 'kh_resources';
  static const String _downloadedFilesBoxName = 'kh_downloaded_files';

  late Box<Course> _coursesBox;
  late Box<ResourceItem> _resourcesBox;
  late Box<String> _downloadedFilesBox;
  bool _isInitialized = false;

  static final KnowledgeHubStorage _instance = KnowledgeHubStorage._internal();

  KnowledgeHubStorage._internal();

  factory KnowledgeHubStorage() {
    return _instance;
  }

  /// Initialize storage boxes
  Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    try {
      _coursesBox = await Hive.openBox<Course>(_coursesBoxName);
      _resourcesBox = await Hive.openBox<ResourceItem>(_resourcesBoxName);
      _downloadedFilesBox = await Hive.openBox<String>(_downloadedFilesBoxName);
      _isInitialized = true;
      logger.i('[KnowledgeHubStorage] Initialized successfully');
    } catch (e) {
      // Handle schema migration errors by clearing corrupted boxes
      if (e.toString().contains('is not a subtype of type')) {
        logger.w(
          '[KnowledgeHubStorage] Schema mismatch detected, clearing boxes for migration',
        );
        try {
          await Hive.deleteBoxFromDisk(_coursesBoxName);
          await Hive.deleteBoxFromDisk(_resourcesBoxName);
          await Hive.deleteBoxFromDisk(_downloadedFilesBoxName);

          // Retry opening boxes
          _coursesBox = await Hive.openBox<Course>(_coursesBoxName);
          _resourcesBox = await Hive.openBox<ResourceItem>(_resourcesBoxName);
          _downloadedFilesBox = await Hive.openBox<String>(
            _downloadedFilesBoxName,
          );
          _isInitialized = true;
          logger.i(
            '[KnowledgeHubStorage] Boxes cleared and reinitialized after schema migration',
          );
        } catch (clearError) {
          logger.e(
            '[KnowledgeHubStorage] Error during schema migration: $clearError',
          );
          rethrow;
        }
      } else {
        logger.e('[KnowledgeHubStorage] Error initializing storage: $e');
        rethrow;
      }
    }
  }

  bool _ensureInitialized({bool throwOnFailure = false}) {
    if (_isInitialized) {
      return true;
    }

    const message =
        '[KnowledgeHubStorage] Accessed before initialization. Call init() first.';
    if (throwOnFailure) {
      throw StateError(message);
    }
    logger.w(message);
    return false;
  }

  // ==================== COURSES ====================

  /// Save courses to local storage
  Future<void> saveCourses(List<Course> courses) async {
    _ensureInitialized(throwOnFailure: true);
    try {
      await _coursesBox.clear();
      for (var course in courses) {
        await _coursesBox.put(course.code, course);
      }
      logger.i('[KnowledgeHubStorage] Saved ${courses.length} courses');
    } catch (e) {
      logger.e('[KnowledgeHubStorage] Error saving courses: $e');
      rethrow;
    }
  }

  /// Get all cached courses
  List<Course> getCachedCourses() {
    if (!_ensureInitialized()) {
      return [];
    }

    try {
      final courses = _coursesBox.values.toList();
      logger.i(
        '[KnowledgeHubStorage] Retrieved ${courses.length} cached courses',
      );
      return courses;
    } catch (e) {
      logger.e('[KnowledgeHubStorage] Error getting cached courses: $e');
      return [];
    }
  }

  /// Check if courses are cached
  bool hasCachedCourses() {
    if (!_ensureInitialized()) {
      return false;
    }

    return _coursesBox.isNotEmpty;
  }

  // ==================== RESOURCES ====================

  /// Save resources for a course (replaces old resources)
  Future<void> saveResourcesForCourse(
    String courseCode,
    List<ResourceItem> resources,
  ) async {
    _ensureInitialized(throwOnFailure: true);
    try {
      // First, clear old resources for this course
      final coursePrefix = '$courseCode:';
      final keysToDelete = _resourcesBox.keys
          .where((key) => key.toString().startsWith(coursePrefix))
          .toList();
      for (var key in keysToDelete) {
        await _resourcesBox.delete(key);
      }

      // Now save the new resources
      for (var resource in resources) {
        final key = '$courseCode:${resource.id}';
        await _resourcesBox.put(key, resource);
      }
      logger.i(
        '[KnowledgeHubStorage] Saved ${resources.length} resources for course $courseCode (cleared ${keysToDelete.length} old resources)',
      );
    } catch (e) {
      logger.e(
        '[KnowledgeHubStorage] Error saving resources for course $courseCode: $e',
      );
      rethrow;
    }
  }

  /// Get cached resources for a course
  List<ResourceItem> getCachedResourcesForCourse(String courseCode) {
    if (!_ensureInitialized()) {
      return [];
    }

    try {
      final coursePrefix = '$courseCode:';
      final resources = _resourcesBox.values.toList().where((resource) {
        // Find the key for this resource and check if it belongs to this course
        for (var key in _resourcesBox.keys) {
          if (key.toString().startsWith(coursePrefix) &&
              _resourcesBox.get(key) == resource) {
            return true;
          }
        }
        return false;
      }).toList();
      logger.i(
        '[KnowledgeHubStorage] Retrieved ${resources.length} cached resources for course $courseCode',
      );
      return resources;
    } catch (e) {
      logger.e(
        '[KnowledgeHubStorage] Error getting cached resources for course $courseCode: $e',
      );
      return [];
    }
  }

  /// Update resource with local file path
  Future<void> updateResourceWithLocalPath(
    String courseCode,
    String resourceId,
    String localFilePath,
  ) async {
    _ensureInitialized(throwOnFailure: true);
    try {
      final key = '$courseCode:$resourceId';
      final resource = _resourcesBox.get(key);
      if (resource != null) {
        final updatedResource = resource.copyWith(localFilePath: localFilePath);
        await _resourcesBox.put(key, updatedResource);
        logger.i(
          '[KnowledgeHubStorage] Updated resource $resourceId with local path',
        );
      }
    } catch (e) {
      logger.e('[KnowledgeHubStorage] Error updating resource: $e');
      rethrow;
    }
  }

  /// Get local file path for resource
  String? getLocalFilePath(String courseCode, String resourceId) {
    if (!_ensureInitialized()) {
      return null;
    }

    try {
      final key = '$courseCode:$resourceId';
      final resource = _resourcesBox.get(key);
      return resource?.localFilePath;
    } catch (e) {
      logger.e('[KnowledgeHubStorage] Error getting local file path: $e');
      return null;
    }
  }

  // ==================== DOWNLOADED FILES ====================

  /// Get app's cache directory for downloaded files
  Future<String> getDownloadsCacheDir() async {
    _ensureInitialized(throwOnFailure: true);
    try {
      final tempDir = await getTemporaryDirectory();
      final downloadsDir = Directory('${tempDir.path}/studently_downloads');

      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      return downloadsDir.path;
    } catch (e) {
      logger.e('[KnowledgeHubStorage] Error getting downloads cache dir: $e');
      rethrow;
    }
  }

  /// Save downloaded file metadata to track which files are downloaded
  Future<void> markFileAsDownloaded(
    String courseCode,
    String resourceId,
    String fileName,
  ) async {
    _ensureInitialized(throwOnFailure: true);
    try {
      final key = '$courseCode:$resourceId:$fileName';
      await _downloadedFilesBox.put(key, fileName);
      logger.i('[KnowledgeHubStorage] Marked file as downloaded: $key');
    } catch (e) {
      logger.e('[KnowledgeHubStorage] Error marking file as downloaded: $e');
      rethrow;
    }
  }

  /// Check if file is already downloaded
  bool isFileDownloaded(String courseCode, String resourceId, String fileName) {
    if (!_ensureInitialized()) {
      return false;
    }

    try {
      final key = '$courseCode:$resourceId:$fileName';
      return _downloadedFilesBox.containsKey(key);
    } catch (e) {
      logger.e(
        '[KnowledgeHubStorage] Error checking if file is downloaded: $e',
      );
      return false;
    }
  }

  /// Clear knowledge hub storage
  Future<void> clearStorage() async {
    _ensureInitialized(throwOnFailure: true);
    try {
      await _coursesBox.clear();
      await _resourcesBox.clear();
      await _downloadedFilesBox.clear();
      logger.i('[KnowledgeHubStorage] Cleared all storage');
    } catch (e) {
      logger.e('[KnowledgeHubStorage] Error clearing storage: $e');
      rethrow;
    }
  }

  /// Get knowledge hub storage statistics
  Map<String, int> getStorageStats() {
    if (!_ensureInitialized()) {
      return {'courses': 0, 'resources': 0, 'downloadedFiles': 0};
    }

    return {
      'courses': _coursesBox.length,
      'resources': _resourcesBox.length,
      'downloadedFiles': _downloadedFilesBox.length,
    };
  }
}
