import 'package:hive_flutter/hive_flutter.dart';
import 'package:studently/models/knowledge_hub.dart';
import 'package:studently/models/notifications.dart';
import 'package:studently/storage/backend_config.dart';
import 'package:studently/storage/knowledge_hub.dart';
import 'package:studently/storage/auth_storage.dart';
import 'package:studently/storage/feed_storage.dart';
import 'package:studently/storage/chat_storage.dart';
import 'package:studently/storage/discover_storage.dart';
import 'package:studently/storage/notifications.dart';
import 'package:studently/logger.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();

  late BackendConfigStorage _backendConfigStorage;
  late KnowledgeHubStorage _knowledgeHubStorage;

  late Box _authBox;
  late Box _feedBox;
  late Box _profileFeedBox;
  late Box _discoverBox;
  late Box _conversationsBox;
  late Box _messagesBox;
  late Box _notificationsBox;

  late AuthStorage _authStorage;
  late FeedStorage _feedStorage;
  late DiscoverStorage _discoverStorage;
  late ChatStorage _chatStorage;
  late NotificationStorage _notificationStorage;

  bool _isAppStorageInitialized = false;
  bool _isUserStorageInitialized = false;
  Future<void>? _appInitFuture;
  Future<void>? _userInitFuture;

  StorageService._internal();

  factory StorageService() {
    return _instance;
  }

  Future<void> initialize() async {
    if (_isAppStorageInitialized) return;
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
      logger.i('[StorageService] Initializing app storage');

      await _initializeHive();

      // Open all the core provider boxes
      _authBox = await Hive.openBox('authBox');
      _feedBox = await Hive.openBox('feedBox');
      _profileFeedBox = await Hive.openBox('profileFeedBox');
      _discoverBox = await Hive.openBox('discoverBox');
      _conversationsBox = await Hive.openBox('conversationsBox');
      _messagesBox = await Hive.openBox('messagesBox');
      _notificationsBox = await Hive.openBox('notificationsBox');

      // Initialize dedicated storage wrappers
      _authStorage = AuthStorage(_authBox);
      _feedStorage = FeedStorage(_feedBox, _profileFeedBox);
      _discoverStorage = DiscoverStorage(_discoverBox);
      _chatStorage = ChatStorage(_conversationsBox, _messagesBox);
      _notificationStorage = NotificationStorage(_notificationsBox);

      // Initialize the dedicated backend config storage
      _backendConfigStorage = BackendConfigStorage();
      await _backendConfigStorage.init();

      _isAppStorageInitialized = true;

      logger.i('[StorageService] App storage initialized successfully');
    } catch (e) {
      logger.e('[StorageService] Error initializing app storage: $e');
      rethrow;
    }
  }

  Future<void> _initializeHive() async {
    await Hive.initFlutter();
    _registerHiveAdapters();
  }

  void _registerHiveAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CourseAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ResourceItemAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(AppNotificationAdapter());
    }
  }

  Future<void> initializeUserStorage() async {
    if (_isUserStorageInitialized) return;
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
      if (!_isAppStorageInitialized) {
        throw Exception(
          'App storage must be initialized first by calling initialize()',
        );
      }

      logger.i('[StorageService] Initializing user storage');

      _knowledgeHubStorage = KnowledgeHubStorage();
      await _knowledgeHubStorage.init();
      _isUserStorageInitialized = true;

      logger.i('[StorageService] User storage initialized successfully');
    } catch (e) {
      logger.e('[StorageService] Error initializing user storage: $e');
      rethrow;
    }
  }

  Future<void> clearUserStorage() async {
    try {
      logger.i('[StorageService] Clearing user storage');

      if (_isAppStorageInitialized) {
        // Clear all boxes that contain user-specific data
        await _authBox.clear(); // Clear auth box (user profile, friends, etc.)
        await _feedBox.clear();
        await _profileFeedBox.clear();
        await _discoverBox.clear();
        await _conversationsBox.clear();
        await _messagesBox.clear();
        await _notificationsBox.clear();

        logger.i('[StorageService] All core storage boxes cleared');
      }

      if (_isUserStorageInitialized) {
        await _knowledgeHubStorage.clearStorage();
        _isUserStorageInitialized = false;
        logger.i('[StorageService] Knowledge Hub storage cleared');
      }

      logger.i('[StorageService] User storage cleanup complete');
    } catch (e) {
      logger.e('[StorageService] Error during user storage cleanup: $e');
      rethrow;
    }
  }

  /// Clears EVERYTHING including app-wide configurations
  Future<void> clearAllStorage() async {
    try {
      logger.i('[StorageService] Clearing ALL storage');

      await clearUserStorage();

      if (_isAppStorageInitialized) {
        await _backendConfigStorage.clearConfig();
        logger.i('[StorageService] Backend config cleared');
      }

      logger.i('[StorageService] Full storage cleanup complete');
    } catch (e) {
      logger.e('[StorageService] Error during full storage cleanup: $e');
      rethrow;
    }
  }

  Box get authBox {
    if (!_isAppStorageInitialized) {
      throw Exception('App storage not initialized.');
    }
    return _authBox;
  }

  Box get feedBox {
    if (!_isAppStorageInitialized) {
      throw Exception('App storage not initialized.');
    }
    return _feedBox;
  }

  Box get profileFeedBox {
    if (!_isAppStorageInitialized) {
      throw Exception('App storage not initialized.');
    }
    return _profileFeedBox;
  }

  DiscoverStorage get discoverStorage {
    if (!_isAppStorageInitialized) {
      throw Exception('App storage not initialized.');
    }
    return _discoverStorage;
  }

  Box get conversationsBox {
    if (!_isAppStorageInitialized) {
      throw Exception('App storage not initialized.');
    }
    return _conversationsBox;
  }

  Box get messagesBox {
    if (!_isAppStorageInitialized) {
      throw Exception('App storage not initialized.');
    }
    return _messagesBox;
  }

  AuthStorage get authStorage {
    if (!_isAppStorageInitialized) {
      throw Exception('App storage not initialized.');
    }
    return _authStorage;
  }

  FeedStorage get feedStorage {
    if (!_isAppStorageInitialized) {
      throw Exception('App storage not initialized.');
    }
    return _feedStorage;
  }

  ChatStorage get chatStorage {
    if (!_isAppStorageInitialized) {
      throw Exception('App storage not initialized.');
    }
    return _chatStorage;
  }

  NotificationStorage get notificationStorage {
    if (!_isAppStorageInitialized) {
      throw Exception('App storage not initialized.');
    }
    return _notificationStorage;
  }

  BackendConfigStorage get backendConfigStorage {
    if (!_isAppStorageInitialized) {
      throw Exception('App storage not initialized.');
    }
    return _backendConfigStorage;
  }

  KnowledgeHubStorage get knowledgeHubStorage {
    if (!_isUserStorageInitialized) {
      throw Exception('User storage not initialized.');
    }
    return _knowledgeHubStorage;
  }

  bool get isAppStorageInitialized => _isAppStorageInitialized;
  bool get isUserStorageInitialized => _isUserStorageInitialized;
}
