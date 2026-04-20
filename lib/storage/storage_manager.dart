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
  Future<void>? _appInitFuture;
  Future<void>? _userInitFuture;

  StorageManager._internal();

  factory StorageManager() {
    return _instance;
  }

  /// Initialize only non-user-specific storage (Backend Config)
  /// Should be called at app startup
  Future<void> initialize() async {
    if (_isBackendConfigInitialized) {
      return;
    }

    if (_appInitFuture != null) {
      await _appInitFuture;
      return;
    }

    _appInitFuture = _initializeInternal();

    try {
      await _appInitFuture;
    } finally {
      _appInitFuture = null;
    }
  }

  Future<void> _initializeInternal() async {
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
    if (_isUserStorageInitialized) {
      return;
    }

    if (_userInitFuture != null) {
      await _userInitFuture;
      return;
    }

    _userInitFuture = _initializeUserStorageInternal();

    try {
      await _userInitFuture;
    } finally {
      _userInitFuture = null;
    }
  }

  Future<void> _initializeUserStorageInternal() async {
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
        await _knowledgeHubStorage.clearStorage();
        _isUserStorageInitialized = false;
        logger.i('[StorageManager] User storage data cleared from KnowledgeHubStorage');
      } else {
        logger.i('[StorageManager] User storage not initialized, nothing to clear');
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
