import 'dart:convert';
import 'dart:io';
import 'package:studently/models/knowledge_hub.dart';
import 'package:studently/services/api.dart';
import 'package:studently/storage/knowledge_hub.dart';
import 'package:studently/logger.dart';
import 'dart:typed_data';

/// Unified KnowledgeHub Repository combining all course and resource operations
class KnowledgeHubRepository {
  // Get the Singleton instance of our API engine
  final ApiService _apiService = ApiService();
  final KnowledgeHubStorage _storage = KnowledgeHubStorage();

  // ==================== COURSE OPERATIONS ====================

  /// Fetch all courses with caching support
  Future<List<Course>> fetchAllCourses({bool forceRefresh = false}) async {
    logger.i("[$runtimeType] Fetch All Courses Initiated (forceRefresh: $forceRefresh)");
    
    try {
      // Check cache first if not forcing refresh
      if (!forceRefresh && _storage.hasCachedCourses()) {
        logger.i("[$runtimeType] Returning cached courses");
        final cachedCourses = _storage.getCachedCourses();
        // Ensure cached courses are sorted
        cachedCourses.sort((a, b) => a.name.compareTo(b.name));
        return cachedCourses;
      }

      // Fetch from API
      final response = await _apiService.get('/hub/courses');
      final List<dynamic> jsonData = jsonDecode(response.body);
      logger.d("[$runtimeType] Fetched ${jsonData.length} courses from API");
      
      final courses = jsonData.where((item) {
        bool hasCode = item['code'] != null;
        bool hasName = item['name'] != null;
        if (!hasCode) {
          logger.w("Discarding course with missing code: ${item['name']}");
        }
        if (!hasName) {
          logger.w("Discarding course with missing name: ${item['code']}");
        }
        return hasCode && hasName;
      }).map((item) => Course.fromJson(item)).toList()
        ..sort((a, b) => a.name.compareTo(b.name)); // Sort by name to match API

      // Cache the results
      await _storage.saveCourses(courses);
      logger.i("[$runtimeType] Cached ${courses.length} courses");
      logger.i("[$runtimeType] Fetch All Courses Completed Successfully");
      
      return courses;
    } catch (e) {
      logger.e("[$runtimeType] Fetch All Courses Failed with error: $e");
      // Try to return cached courses as fallback
      if (_storage.hasCachedCourses()) {
        logger.i("[$runtimeType] Returning cached courses as fallback");
        final cachedCourses = _storage.getCachedCourses();
        // Ensure cached courses are sorted
        cachedCourses.sort((a, b) => a.name.compareTo(b.name));
        return cachedCourses;
      }
      rethrow;
    }
  }

  // ==================== RESOURCE OPERATIONS ====================

  Future<List<ResourceGroup>> fetchResourceGroups({bool forceRefresh = false}) async {
    logger.i("[$runtimeType] Fetch Resource Groups Initiated (forceRefresh: $forceRefresh)");
    try {
      final response = await _apiService.get('/hub/resources');
      final List<dynamic> jsonData = jsonDecode(response.body);
      logger.d("[$runtimeType] Fetched ${jsonData.length} resource groups from API");
      logger.i("[$runtimeType] Fetch Resource Groups Completed Successfully");
      
      return jsonData.map((item) => ResourceGroup.fromJson(item)).toList();
    } catch (e) {
      logger.e("[$runtimeType] Fetch Resource Groups Failed with error: $e");
      rethrow;
    }
  }

  /// Fetch resources for a course with caching support
  Future<ResourceGroup> fetchResourcesByCourse(String courseId, {bool forceRefresh = false}) async {
    logger.i("[$runtimeType] Fetch Resources for Course $courseId Initiated (forceRefresh: $forceRefresh)");
    try {
      // Check cache first if not forcing refresh
      if (!forceRefresh) {
        final cachedResources = _storage.getCachedResourcesForCourse(courseId);
        if (cachedResources.isNotEmpty) {
          logger.i("[$runtimeType] Returning cached resources for course $courseId");
          // Reconstruct ResourceGroup properly from cached resources
          final Map<String, List<ResourceItem>> resourcesByType = {};
          for (var resource in cachedResources) {
            final type = (resource.type ?? '').toLowerCase();
            if (!resourcesByType.containsKey(type)) {
              resourcesByType[type] = [];
            }
            resourcesByType[type]!.add(resource);
          }
          return ResourceGroup(
            course: Course(code: courseId, name: courseId),
            resources: resourcesByType,
          );
        }
      }

      // Fetch from API
      final response = await _apiService.get('/hub/resources/$courseId');
      final Map<String, dynamic> jsonData = jsonDecode(response.body);
      final resourceGroup = ResourceGroup.fromJson(jsonData);

      // Cache the resources with proper type information
      final allResources = <ResourceItem>[];
      resourceGroup.resources.forEach((type, resourceList) {
        for (var resource in resourceList) {
          // Add type information to each resource
          allResources.add(resource.copyWith(type: type));
        }
      });
      await _storage.saveResourcesForCourse(courseId, allResources);
      logger.i("[$runtimeType] Cached ${allResources.length} resources for course $courseId");
      logger.i("[$runtimeType] Fetch Resources for Course $courseId Completed Successfully");
      
      return resourceGroup;
    } catch (e) {
      logger.e("[$runtimeType] Fetch Resources for Course $courseId Failed with error: $e");
      // Try to return cached resources as fallback
      final cachedResources = _storage.getCachedResourcesForCourse(courseId);
      if (cachedResources.isNotEmpty) {
        logger.i("[$runtimeType] Returning cached resources for course $courseId as fallback");
        return ResourceGroup(
          course: Course(code: courseId, name: courseId),
          resources: {
            'cached': cachedResources,
          },
        );
      }
      rethrow;
    }
  }

  String getDownloadUrl(String resourceId) {
    logger.i("[$runtimeType] Get Download URL for Resource $resourceId");
    final completeUrl = _apiService.getCompleteUrl('/hub/resources/$resourceId/download');
    logger.d("[$runtimeType] Download URL: $completeUrl");
    return completeUrl;
  }

  /// Download resource file and save locally
  Future<Uint8List> downloadResourceFile(
    String resourceId, {
    String courseCode = '',
  }) async {
    logger.i("[$runtimeType] Download Resource File for Resource $resourceId Initiated (courseCode: $courseCode)");
    try {
      final response = await _apiService.get('/hub/resources/$resourceId/download');
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        logger.i("[$runtimeType] Downloaded ${bytes.length} bytes for resource $resourceId");
        
        // Mark file as downloaded in local storage
        if (courseCode.isNotEmpty) {
          await _storage.markFileAsDownloaded(courseCode, resourceId, resourceId);
          logger.i("[$runtimeType] Marked resource $resourceId as downloaded in local storage");
        }
        
        logger.i("[$runtimeType] Download Resource File for Resource $resourceId Completed Successfully");
        return bytes;
      } else {
        logger.e("[$runtimeType] Download Resource File for Resource $resourceId Failed with status code: ${response.statusCode}");
        throw Exception('Failed to download resource file. Status code: ${response.statusCode}');
      }
    } catch (e) {
      logger.e("[$runtimeType] Download Resource File for Resource $resourceId Failed with error: $e");
      rethrow;
    }
  }

  /// Update resource with local file path
  Future<void> updateResourceLocalPath(
    String courseCode,
    String resourceId,
    String localFilePath,
  ) async {
    logger.i("[$runtimeType] Updating resource $resourceId with local path: $localFilePath");
    try {
      await _storage.updateResourceWithLocalPath(
        courseCode,
        resourceId,
        localFilePath,
      );
      logger.i("[$runtimeType] Successfully updated resource $resourceId with local path");
    } catch (e) {
      logger.e("[$runtimeType] Error updating resource local path: $e");
      rethrow;
    }
  }

  /// Get local file path for a resource
  String? getLocalFilePath(String courseCode, String resourceId) {
    return _storage.getLocalFilePath(courseCode, resourceId);
  }

  Future<void> uploadResource({
    required ResourceItemRequest resourceItemRequest,
    required String filePath,
  }) async {
    logger.i("[$runtimeType] Upload Resource Initiated for Course ${resourceItemRequest.course.code}");
    try {
      await _apiService.multiPart(
        file: File(filePath),
        metadata: resourceItemRequest.toJson(),
      );
      logger.i("[$runtimeType] Upload Resource Completed Successfully for Course ${resourceItemRequest.course.code}");
    } catch (e) {
      logger.e("[$runtimeType] Upload Resource Failed for Course ${resourceItemRequest.course.code} with error: $e");
      rethrow;
    }
  }

  /// Upload resource using bytes (web-compatible)
  Future<void> uploadResourceFromBytes({
    required ResourceItemRequest resourceItemRequest,
    required List<int> fileBytes,
    required String filename,
  }) async {
    logger.i("[$runtimeType] Upload Resource (bytes) Initiated for Course ${resourceItemRequest.course.code}");
    try {
      await _apiService.multiPartFromBytes(
        endpoint: '/hub/resources/upload',
        fileBytes: fileBytes,
        filename: filename,
        metadata: resourceItemRequest.toJson(),
      );
      logger.i("[$runtimeType] Upload Resource (bytes) Completed Successfully for Course ${resourceItemRequest.course.code}");
    } catch (e) {
      logger.e("[$runtimeType] Upload Resource (bytes) Failed for Course ${resourceItemRequest.course.code} with error: $e");
      rethrow;
    }
  }
}

// ==================== LEGACY ALIASES ====================
// Keep these for backward compatibility during migration

class CourseRepository extends KnowledgeHubRepository {}

class ResourceRepository extends KnowledgeHubRepository {}
