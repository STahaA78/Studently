import 'dart:convert';
import 'package:studently/models/resource.dart';
import 'package:studently/services/api.dart';
import 'package:studently/logger.dart';

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
}
