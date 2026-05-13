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
    CacheDomain.feedPosts: CachePolicy(ttl: Duration(seconds: 30)),
    CacheDomain.notifications: CachePolicy(ttl: Duration(seconds: 20)),
    CacheDomain.knowledgeCourses: CachePolicy(ttl: Duration(seconds: 60)),
    CacheDomain.knowledgeCourseResources: CachePolicy(ttl: Duration(seconds: 45)),
  };

  String _key(CacheDomain domain, String? scopeId) => '${domain.name}:${scopeId ?? "_"}';

  bool isStale(CacheDomain domain, {String? scopeId}) {
    final key = _key(domain, scopeId);
    final last = _lastFreshAt[key];
    if (last == null) return true;
    final ttl = policies[domain]?.ttl ?? const Duration(seconds: 30);
    return DateTime.now().difference(last) > ttl;
  }

  void markFresh(CacheDomain domain, {String? scopeId}) {
    _lastFreshAt[_key(domain, scopeId)] = DateTime.now();
  }

  void invalidate(CacheDomain domain, {String? scopeId}) {
    _lastFreshAt.remove(_key(domain, scopeId));
  }

  void invalidateMany(List<(CacheDomain, String?)> keys) {
    for (final key in keys) {
      invalidate(key.$1, scopeId: key.$2);
    }
  }

  bool tryBeginRefresh(CacheDomain domain, {String? scopeId}) {
    final key = _key(domain, scopeId);
    if (_inFlight.contains(key)) return false;
    _inFlight.add(key);
    return true;
  }

  void endRefresh(CacheDomain domain, {String? scopeId, bool success = true}) {
    final key = _key(domain, scopeId);
    _inFlight.remove(key);
    if (success) {
      markFresh(domain, scopeId: scopeId);
    }
  }
}

class CacheInvalidationBus extends Notifier<int> {
  @override
  int build() => 0;

  final List<CacheInvalidationEvent> _events = [];

  void publish(CacheInvalidationEvent event) {
    _events.add(event);
    state++;
    logger.d('[CacheInvalidationBus] event=${event.type} user=${event.userId} course=${event.courseId}');
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
