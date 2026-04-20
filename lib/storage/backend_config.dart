import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:studently/models/backend_config.dart';
import 'package:studently/logger.dart';

/// Service for managing local storage of backend configuration
/// Handles caching of departments, interests, batch ranges, allowed email domains, etc.
class BackendConfigStorage {
  static const String _boxName = 'backend_config_storage';
  static const String _configKey = 'config';

  late Box<String> _configBox;
  bool _isInitialized = false;

  static final BackendConfigStorage _instance =
      BackendConfigStorage._internal();

  BackendConfigStorage._internal();

  factory BackendConfigStorage() {
    return _instance;
  }

  /// Initialize storage box
  Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    try {
      _configBox = await Hive.openBox<String>(_boxName);
      _isInitialized = true;
      logger.i('[BackendConfigStorage] Initialized successfully');
    } catch (e) {
      if (e.toString().contains('is not a subtype of type')) {
        logger.w('[BackendConfigStorage] Schema mismatch detected, clearing boxes for migration');
        try {
          await Hive.deleteBoxFromDisk(_boxName);
          _configBox = await Hive.openBox<String>(_boxName);
          _isInitialized = true;
          logger.i('[BackendConfigStorage] Box cleared and reinitialized after schema migration');
        } catch (clearError) {
          logger.e('[BackendConfigStorage] Error during schema migration: $clearError');
          rethrow;
        }
      } else {
        logger.e('[BackendConfigStorage] Error initializing storage: $e');
        rethrow;
      }
    }
  }

  /// Save backend config to local storage
  Future<void> saveConfig(BackendConfig config) async {
    if (!_isInitialized) {
      await init();
    }

    try {
      final configJson = jsonEncode({
        'departments': config.departments
            .map((d) => {'name': d.name, 'code': d.code})
            .toList(),
        'interests': config.interests
            .map((i) => {
          'category': i.category,
          'data': i.data
              .map((d) => {'name': d.name, 'emoji': d.emoji})
              .toList(),
        })
            .toList(),
        'batch_range': {
          'start': config.batchRange.start,
          'end': config.batchRange.end
        },
        'current_term': {
          'semester': config.currentTerm.term,
          'year': config.currentTerm.year
        },
        'allowed_email_domains': config.allowedEmailDomains,
      });
      
      await _configBox.put(_configKey, configJson);
      logger.i('[BackendConfigStorage] Config cached successfully');
    } catch (e) {
      logger.e('[BackendConfigStorage] Error saving config: $e');
      rethrow;
    }
  }

  /// Get cached backend config
  BackendConfig? getCachedConfig() {
    if (!_isInitialized) {
      logger.w('[BackendConfigStorage] Accessed before initialization. Returning null config.');
      return null;
    }

    try {
      final configJson = _configBox.get(_configKey);
      if (configJson != null) {
        logger.d('[BackendConfigStorage] Retrieved cached config');
        return BackendConfig.fromJson(jsonDecode(configJson));
      }
      return null;
    } catch (e) {
      logger.e('[BackendConfigStorage] Error getting cached config: $e');
      return null;
    }
  }

  /// Check if config is cached
  bool hasCachedConfig() {
    if (!_isInitialized) {
      logger.w('[BackendConfigStorage] Accessed before initialization. No cached config available.');
      return false;
    }

    try {
      return _configBox.containsKey(_configKey);
    } catch (e) {
      logger.e('[BackendConfigStorage] Error checking cached config: $e');
      return false;
    }
  }

  /// Clear cached config
  Future<void> clearConfig() async {
    if (!_isInitialized) {
      logger.w('[BackendConfigStorage] Clear requested before initialization. Nothing to clear.');
      return;
    }

    try {
      await _configBox.delete(_configKey);
      logger.i('[BackendConfigStorage] Config cleared');
    } catch (e) {
      logger.e('[BackendConfigStorage] Error clearing config: $e');
      rethrow;
    }
  }
}
