import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:studently/config.dart';
import 'package:studently/models/backend_config.dart';
import 'package:studently/logger.dart';
import 'package:studently/services/storage.dart';

class BackendConfigRepository {
  Future<BackendConfig> fetchConfig() async {
    logger.i("[$runtimeType] Fetch Backend Config Initiated");
    try {
      final cachedConfig = getCachedConfig();
      final headers = <String, String>{'Content-Type': 'application/json'};
      final cachedVersion = cachedConfig?.version;
      if (cachedVersion != null) {
        headers['If-None-Match'] = '"$cachedVersion"';
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/config'),
        headers: headers,
      );

      if (response.statusCode == 304 && cachedConfig != null) {
        logger.i("[$runtimeType] Backend config unchanged (304)");
        return cachedConfig;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Request failed with status: ${response.statusCode}');
      }

      final configData = jsonDecode(response.body);
      final config = BackendConfig.fromJson(configData);

      final etag = response.headers['etag'];
      if (etag != null && etag.isNotEmpty) {
        final normalized = etag.replaceAll('"', '');
        final parsedVersion = int.tryParse(normalized);
        if (parsedVersion != null) {
          config.version = parsedVersion;
        }
      }

      // Cache the config in storage
      await StorageService().backendConfigStorage.saveConfig(config);

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
      final cachedConfig = StorageService().backendConfigStorage.getCachedConfig();
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
