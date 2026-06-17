import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/logger.dart';

enum CacheDomain {
  userProfile,
  friendsList,
  chatConversations,
  chatUserProfiles,
  feedPosts,
  notifications,
  knowledgeCourses,
  knowledgeCourseResources,
  backendConfig,
  teachers,
  teacherReviews,
}

class CachePolicy {
  final Duration ttl;
  final bool allowBackgroundRefresh;

  const CachePolicy({required this.ttl, this.allowBackgroundRefresh = true});
}

class CacheInvalidationEvent {
  final String type;
  final String? userId;
  final String? courseId;

  const CacheInvalidationEvent({
    required this.type,
    this.userId,
    this.courseId,
  });
}

class CacheCoordinator {
  final Map<String, DateTime> _lastFreshAt = {};
  final Set<String> _inFlight = {};

  static const Map<CacheDomain, CachePolicy> policies = {
    CacheDomain.userProfile: CachePolicy(ttl: Duration(seconds: 60)),
    CacheDomain.friendsList: CachePolicy(ttl: Duration(seconds: 60)),
    CacheDomain.chatConversations: CachePolicy(ttl: Duration(seconds: 30)),
    CacheDomain.chatUserProfiles: CachePolicy(ttl: Duration(seconds: 45)),
    CacheDomain.feedPosts: CachePolicy(ttl: Duration(seconds: 60)),
    CacheDomain.notifications: CachePolicy(ttl: Duration(seconds: 20)),
    CacheDomain.knowledgeCourses: CachePolicy(ttl: Duration(seconds: 60)),
    CacheDomain.knowledgeCourseResources: CachePolicy(
      ttl: Duration(seconds: 45),
    ),
    CacheDomain.backendConfig: CachePolicy(ttl: Duration(seconds: 30)),
    CacheDomain.teachers: CachePolicy(ttl: Duration(seconds: 60)),
    CacheDomain.teacherReviews: CachePolicy(ttl: Duration(seconds: 45)),
  };

  String _key(CacheDomain domain, String? scopeId) =>
      '${domain.name}:${scopeId ?? "_"}';

  bool isStale(CacheDomain domain, {String? scopeId}) {
    final key = _key(domain, scopeId);
    final last = _lastFreshAt[key];
    if (last == null) {
      logger.d(
        '[CacheCoordinator] isStale key=$key result=true reason=missing',
      );
      return true;
    }
    final ttl = policies[domain]?.ttl ?? const Duration(seconds: 30);
    final stale = DateTime.now().difference(last) > ttl;
    logger.d(
      '[CacheCoordinator] isStale key=$key result=$stale ttl=${ttl.inSeconds}s',
    );
    return stale;
  }

  void markFresh(CacheDomain domain, {String? scopeId}) {
    final key = _key(domain, scopeId);
    _lastFreshAt[key] = DateTime.now();
    logger.d('[CacheCoordinator] markFresh key=$key');
  }

  void invalidate(CacheDomain domain, {String? scopeId}) {
    final key = _key(domain, scopeId);
    _lastFreshAt.remove(key);
    logger.d('[CacheCoordinator] invalidate key=$key');
  }

  void invalidateMany(List<(CacheDomain, String?)> keys) {
    for (final key in keys) {
      invalidate(key.$1, scopeId: key.$2);
    }
  }

  bool tryBeginRefresh(CacheDomain domain, {String? scopeId}) {
    final key = _key(domain, scopeId);
    if (_inFlight.contains(key)) {
      logger.d(
        '[CacheCoordinator] tryBeginRefresh key=$key result=false reason=in_flight',
      );
      return false;
    }
    _inFlight.add(key);
    logger.d('[CacheCoordinator] tryBeginRefresh key=$key result=true');
    return true;
  }

  void endRefresh(CacheDomain domain, {String? scopeId, bool success = true}) {
    final key = _key(domain, scopeId);
    _inFlight.remove(key);
    logger.d('[CacheCoordinator] endRefresh key=$key success=$success');
    if (success) {
      markFresh(domain, scopeId: scopeId);
    }
  }

  Duration? timeUntilStale(CacheDomain domain, {String? scopeId}) {
    final key = _key(domain, scopeId);
    final last = _lastFreshAt[key];
    if (last == null) return Duration.zero;

    final ttl = policies[domain]?.ttl ?? const Duration(seconds: 30);
    final elapsed = DateTime.now().difference(last);
    final remaining = ttl - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

class CacheInvalidationBus extends Notifier<int> {
  @override
  int build() => 0;

  final List<CacheInvalidationEvent> _events = [];

  void publish(CacheInvalidationEvent event) {
    _events.add(event);
    state++;
    logger.d(
      '[CacheInvalidationBus] event=${event.type} user=${event.userId} course=${event.courseId}',
    );
  }

  CacheInvalidationEvent? latest() => _events.isEmpty ? null : _events.last;
}

final cacheCoordinatorProvider = Provider<CacheCoordinator>((ref) {
  return CacheCoordinator();
});

final cacheInvalidationBusProvider =
    NotifierProvider<CacheInvalidationBus, int>(() {
      return CacheInvalidationBus();
    });
