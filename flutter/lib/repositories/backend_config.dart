import 'package:studently/services/api.dart';
import 'dart:convert';
import 'package:studently/models/backend_config.dart';
import 'package:studently/logger.dart';

class BackendConfigRepository {
  final ApiService _apiService = ApiService();

  Future<BackendConfig> fetchConfig() async {
    logger.i("[$runtimeType] Fetch Backend Config Initiated");
    try {
      final response = await _apiService.get('/config');
      final configData = jsonDecode(response.body);
      logger.i("[$runtimeType] Fetch Backend Config Completed Successfully");
      return BackendConfig.fromJson(configData);
    } catch (e) {
      logger.e("[$runtimeType] Fetch Backend Config Failed with error: $e");
      rethrow;
    }
  }
}