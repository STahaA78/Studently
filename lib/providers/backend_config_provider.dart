import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/models/backend_config.dart';
import 'package:studently/providers/cache_freshness_provider.dart';
import 'package:studently/repositories/backend_config.dart';
import 'package:studently/logger.dart';

class BackendConfigNotifier extends AsyncNotifier<BackendConfig> {
  late final BackendConfigRepository _repository = BackendConfigRepository();
  Timer? _refreshTimer;

  @override
  Future<BackendConfig> build() async {
    logger.i("[$runtimeType] build() started - Loading BackendConfig");
    ref.keepAlive();
    ref.onDispose(() {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    });

    final cache = ref.read(cacheCoordinatorProvider);

    // 1. Try to get cached config from Hive (synchronous)
    final cachedConfig = _repository.getCachedConfig();

    _startRefreshTimer();

    if (cachedConfig != null) {
      logger.d(
        "[$runtimeType] Cached config found, returning and refreshing in background",
      );
      if (cache.isStale(CacheDomain.backendConfig)) {
        Future(() => _refreshConfigInBackground());
      }
      return cachedConfig;
    }

    // 2. No cache found, fetch fresh from API
    logger.d("[$runtimeType] No cached config, fetching fresh from API");
    final freshConfig = await _repository.fetchConfig();
    cache.markFresh(CacheDomain.backendConfig);
    return freshConfig;
  }

  void _startRefreshTimer() {
    if (_refreshTimer != null) return;

    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      silentRefresh();
    });
  }

  Future<void> silentRefresh() async {
    final cache = ref.read(cacheCoordinatorProvider);
    if (!cache.isStale(CacheDomain.backendConfig)) {
      return;
    }
    await _refreshConfigInBackground();
  }

  /// Refresh config in the background without blocking UI
  Future<void> _refreshConfigInBackground() async {
    final cache = ref.read(cacheCoordinatorProvider);
    if (!cache.tryBeginRefresh(CacheDomain.backendConfig)) {
      return;
    }
    try {
      logger.d("[$runtimeType] Background config refresh started");
      final freshConfig = await _repository.fetchConfig();
      state = AsyncValue.data(freshConfig);
      cache.endRefresh(CacheDomain.backendConfig, success: true);
      logger.d("[$runtimeType] Background config refresh completed");
    } catch (e) {
      cache.endRefresh(CacheDomain.backendConfig, success: false);
      logger.w("[$runtimeType] Background config refresh failed: $e");
      // Don't update state on error - keep using cached data
    }
  }

  /// Force refresh config immediately
  Future<void> refreshConfig() async {
    final cache = ref.read(cacheCoordinatorProvider);
    cache.invalidate(CacheDomain.backendConfig);
    state = const AsyncValue.loading();
    try {
      final freshConfig = await _repository.fetchConfig();
      state = AsyncValue.data(freshConfig);
      cache.markFresh(CacheDomain.backendConfig);
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
