import 'dart:convert';
import 'package:studently/models/course.dart';
import 'package:studently/services/api.dart';
import 'package:studently/logger.dart';

class CourseRepository {
  // Get the Singleton instance of our API engine
  final ApiService _apiService = ApiService();

  Future<List<Course>> fetchAllCourses() async {
    logger.i("[$runtimeType] Fetch All Courses Initiated");
    try {
      // 1. Call the API (endpoint depends on your backend)
      final response = await _apiService.get('/hub/courses');

      // 2. Decode the body (which is a List of Maps)
      final List<dynamic> jsonData = jsonDecode(response.body);
      logger.d("[$runtimeType] Fetched ${jsonData.length} courses from API");
      logger.i("[$runtimeType] Fetch All Courses Completed Successfully");
      // 3. Map the JSON list into a List of Course objects
      return jsonData.where((item) {
        bool hasCode = item['code'] != null;
        bool hasName = item['name'] != null;
        if (!hasCode) {
          logger.w("Discarding course with missing code: ${item['name']}");
        }
        if (!hasName) {
            logger.w("Discarding course with missing name: ${item['code']}");
          }
        return hasCode && hasName;
      }).map((item) => Course.fromJson(item)).toList();
      
    } catch (e) {
      // Log error using your logger
      logger.e("[$runtimeType] Fetch All Courses Failed with error: $e");
      rethrow;
    }
  }
}