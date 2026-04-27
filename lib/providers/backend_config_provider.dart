import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/models/backend_config.dart';
import 'package:studently/repositories/backend_config.dart';
import 'package:studently/logger.dart';

class BackendConfigNotifier extends AsyncNotifier<BackendConfig> {
  late final BackendConfigRepository _repository = BackendConfigRepository();

  @override
  Future<BackendConfig> build() async {
    logger.i("[$runtimeType] build() started - Loading BackendConfig");

    // 1. Try to get cached config from Hive (synchronous)
    final cachedConfig = _repository.getCachedConfig();

    if (cachedConfig != null) {
      logger.d(
        "[$runtimeType] Cached config found, returning and refreshing in background",
      );
      // Return cached data immediately
      Future(() => _refreshConfigInBackground());
      return cachedConfig;
    }

    // 2. No cache found, fetch fresh from API
    logger.d("[$runtimeType] No cached config, fetching fresh from API");
    return await _repository.fetchConfig();
  }

  /// Refresh config in the background without blocking UI
  Future<void> _refreshConfigInBackground() async {
    try {
      logger.d("[$runtimeType] Background config refresh started");
      final freshConfig = await _repository.fetchConfig();
      state = AsyncValue.data(freshConfig);
      logger.d("[$runtimeType] Background config refresh completed");
    } catch (e) {
      logger.w("[$runtimeType] Background config refresh failed: $e");
      // Don't update state on error - keep using cached data
    }
  }

  /// Force refresh config immediately
  Future<void> refreshConfig() async {
    state = const AsyncValue.loading();
    try {
      final freshConfig = await _repository.fetchConfig();
      state = AsyncValue.data(freshConfig);
      logger.i("[$runtimeType] Config refreshed successfully");
    } catch (e) {
      logger.e("[$runtimeType] Config refresh failed", error: e);
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final backendConfigProvider =
    AsyncNotifierProvider<BackendConfigNotifier, BackendConfig>(() {
      return BackendConfigNotifier();
    });
