import 'package:hive_flutter/hive_flutter.dart';
import 'package:studently/models/knowledge_hub.dart';

/// Centralized Hive initialization and adapter registration
/// This keeps all Hive setup in one place, making it easy to maintain
class HiveInit {
  /// Initialize Hive and register all adapters
  static Future<void> initializeHive() async {
    await Hive.initFlutter();
    _registerAllAdapters();
  }

  /// Register all Hive adapters in one place
  /// Add new adapters here as you create new models
  static void _registerAllAdapters() {
    // KnowledgeHub adapters
    Hive.registerAdapter(CourseAdapter());
    Hive.registerAdapter(ResourceItemAdapter());

    // Add new model adapters here as needed
    // Hive.registerAdapter(MyNewModelAdapter());
  }
}
