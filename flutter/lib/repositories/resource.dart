import 'dart:convert';
import 'dart:io';
import 'package:studently/models/resource.dart';
import 'package:studently/services/api.dart';
import 'package:studently/logger.dart';
import 'dart:typed_data';

class ResourceRepository {
  // Get the Singleton instance of our API engine
  final ApiService _apiService = ApiService();

  // Fetch all approved resource groups for all courses
  Future<List<ResourceGroup>> fetchResourceGroups() async {
    logger.i("[$runtimeType] Fetch Resource Groups Initiated");
    try {
      // 1. Call the API (endpoint depends on your backend)
      final response = await _apiService.get('/hub/resources');
      // 2. Decode the body (which is a List of Maps)
      final List<dynamic> jsonData = jsonDecode(response.body);
      logger.d("[$runtimeType] Fetched ${jsonData.length} resource groups from API");
      logger.i("[$runtimeType] Fetch Resource Groups Completed Successfully");
      // 3. Map the JSON list into a List of ResourceGroup objects
      return jsonData.map((item) => ResourceGroup.fromJson(item)).toList();
    } catch (e) {
      // Log error using your logger
      logger.e("[$runtimeType] Fetch Resource Groups Failed with error: $e");
      rethrow;
    }
  }

  Future<ResourceGroup> fetchResourcesByCourse(String courseId) async {
    logger.i("[$runtimeType] Fetch Resources for Course $courseId Initiated");
    try {
      // 1. Call the API (endpoint depends on your backend)
      final response = await _apiService.get('/hub/resources/$courseId');
      // 2. Decode the body (which is a Map)
      final Map<String, dynamic> jsonData = jsonDecode(response.body);
      logger.i("[$runtimeType] Fetch Resources for Course $courseId Completed Successfully");
      // 3. Map the JSON into a ResourceGroup object
      return ResourceGroup.fromJson(jsonData);
    } catch (e) {
      // Log error using your logger
      logger.e("[$runtimeType] Fetch Resources for Course $courseId Failed with error: $e");
      rethrow;
    }
  }

  String getDownloadUrl(String resourceId) {
    // Assuming your backend serves files from a specific base URL
    logger.i("[$runtimeType] Get Download URL for Resource $resourceId");
    final completeUrl = _apiService.getCompleteUrl('/hub/resources/$resourceId/download?t=${DateTime.now().millisecondsSinceEpoch}');
    logger.d("[$runtimeType] Download URL: $completeUrl");
    return completeUrl;
  }

  Future<Uint8List> downloadResourceFile(String resourceId) async {
    logger.i("[$runtimeType] Download Resource File for Resource $resourceId Initiated");
    try {
      final response = await _apiService.get('/hub/resources/$resourceId/download');
      if (response.statusCode == 200) {
        logger.i("[$runtimeType] Download Resource File for Resource $resourceId Completed Successfully. Recevied ${response.bodyBytes.length} bytes");
        return response.bodyBytes;
      } else {
        logger.e("[$runtimeType] Download Resource File for Resource $resourceId Failed with status code: ${response.statusCode}");
        throw Exception('Failed to download resource file. Status code: ${response.statusCode}');
      }
    } catch (e) {
      logger.e("[$runtimeType] Download Resource File for Resource $resourceId Failed with error: $e");
      rethrow;
    }
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
}
