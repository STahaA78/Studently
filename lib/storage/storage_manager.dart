import 'package:studently/storage/backend_config.dart';
import 'package:studently/storage/knowledge_hub.dart';
import 'package:studently/logger.dart';

/// Central manager for all app storage operations
/// 
/// Responsibilities:
/// - Manages BackendConfigStorage (initialized at app startup)
/// - Manages KnowledgeHubStorage (initialized only when user is logged in)
/// 
/// Usage:
/// - Call [StorageManager.initialize()] at app startup
/// - Call [StorageManager.initializeUserStorage()] when user logs in
/// - Call [StorageManager.clearUserStorage()] when user logs out
class StorageManager {
  static final StorageManager _instance = StorageManager._internal();

  late BackendConfigStorage _backendConfigStorage;
  late KnowledgeHubStorage _knowledgeHubStorage;

  bool _isBackendConfigInitialized = false;
  bool _isUserStorageInitialized = false;

  StorageManager._internal();

  factory StorageManager() {
    return _instance;
  }

  /// Initialize only non-user-specific storage (Backend Config)
  /// Should be called at app startup
  Future<void> initialize() async {
    try {
      logger.i('[StorageManager] Initializing app storage');
      
      _backendConfigStorage = BackendConfigStorage();
      await _backendConfigStorage.init();
      _isBackendConfigInitialized = true;

      logger.i('[StorageManager] App storage initialized successfully');
    } catch (e) {
      logger.e('[StorageManager] Error initializing app storage: $e');
      rethrow;
    }
  }

  /// Initialize user-specific storage (Knowledge Hub)
  /// Should be called when user logs in
  Future<void> initializeUserStorage() async {
    try {
      if (!_isBackendConfigInitialized) {
        throw Exception('App storage must be initialized first by calling initialize()');
      }

      logger.i('[StorageManager] Initializing user storage');
      
      _knowledgeHubStorage = KnowledgeHubStorage();
      await _knowledgeHubStorage.init();
      _isUserStorageInitialized = true;

      logger.i('[StorageManager] User storage initialized successfully');
    } catch (e) {
      logger.e('[StorageManager] Error initializing user storage: $e');
      rethrow;
    }
  }

  /// Clear all user-specific storage
  /// Should be called when user logs out
  Future<void> clearUserStorage() async {
    try {
      logger.i('[StorageManager] Clearing user storage');
      
      if (_isUserStorageInitialized) {
        // You can add methods to KnowledgeHubStorage to clear all data if needed
        // For now, the instance will be recreated on re-login
        _isUserStorageInitialized = false;
      }

      logger.i('[StorageManager] User storage cleared');
    } catch (e) {
      logger.e('[StorageManager] Error clearing user storage: $e');
      rethrow;
    }
  }

  /// Get BackendConfigStorage instance (available after initialize())
  BackendConfigStorage get backendConfigStorage {
    if (!_isBackendConfigInitialized) {
      throw Exception('BackendConfigStorage not initialized. Call initialize() first');
    }
    return _backendConfigStorage;
  }

  /// Get KnowledgeHubStorage instance (available after initializeUserStorage())
  KnowledgeHubStorage get knowledgeHubStorage {
    if (!_isUserStorageInitialized) {
      throw Exception('KnowledgeHubStorage not initialized. Call initializeUserStorage() first');
    }
    return _knowledgeHubStorage;
  }

  /// Check if app storage is initialized
  bool get isAppStorageInitialized => _isBackendConfigInitialized;

  /// Check if user storage is initialized
  bool get isUserStorageInitialized => _isUserStorageInitialized;
}
