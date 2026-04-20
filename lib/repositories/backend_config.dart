import 'package:studently/services/api.dart';
import 'dart:convert';
import 'package:studently/models/backend_config.dart';
import 'package:studently/logger.dart';
import 'package:studently/storage/storage_manager.dart';

class BackendConfigRepository {
  final ApiService _apiService = ApiService();

  Future<BackendConfig> fetchConfig() async {
    logger.i("[$runtimeType] Fetch Backend Config Initiated");
    try {
      final response = await _apiService.get('/config');
      final configData = jsonDecode(response.body);
      final config = BackendConfig.fromJson(configData);
      
      // Cache the config in storage
      await StorageManager().backendConfigStorage.saveConfig(config);
      
      logger.i("[$runtimeType] Fetch Backend Config Completed Successfully");
      return config;
    } catch (e) {
      logger.e("[$runtimeType] Fetch Backend Config Failed with error: $e");
      rethrow;
    }
  }

  /// Get cached config from storage (synchronous)
  BackendConfig? getCachedConfig() {
    try {
      final cachedConfig = StorageManager().backendConfigStorage.getCachedConfig();
      if (cachedConfig != null) {
        logger.d("[$runtimeType] Retrieved cached config from storage");
      }
      return cachedConfig;
    } catch (e) {
      logger.w("[$runtimeType] Error retrieving cached config: $e");
    }
    return null;
  }
}