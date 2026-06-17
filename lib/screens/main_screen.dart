import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/services/analytics_service.dart';
import 'community_feed_page.dart';
import 'discover_main.dart';
import 'profile_main.dart';
import 'knowledge_hub_main.dart';
import 'teachers_main.dart';
import '../widgets/custom_nav_bar.dart';

class NavigationIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    if (state == index) return;
    state = index;
    unawaited(
      AnalyticsService.logScreenView(
        screenName: _mainScreenNameForIndex(index),
        screenClass: 'MainScreen',
      ),
    );
  }
}

String _mainScreenNameForIndex(int index) {
  switch (index) {
    case 1:
      return 'discover';
    case 3:
      return 'knowledge_hub';
    case 4:
      return 'teachers';
    case 5:
      return 'profile';
    case 0:
    default:
      return 'community_feed';
  }
}

final navigationIndexProvider = NotifierProvider<NavigationIndexNotifier, int>(
  () {
    return NavigationIndexNotifier();
  },
);

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  bool _loggedInitialSection = false;

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);

    if (!_loggedInitialSection) {
      _loggedInitialSection = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          AnalyticsService.logScreenView(
            screenName: _mainScreenNameForIndex(currentIndex),
            screenClass: 'MainScreen',
          ),
        );
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. PERSISTENT PAGES (Preserve scroll/state)
          Offstage(
            offstage: currentIndex != 0,
            child: const CommunityFeedPage(),
          ),
          Offstage(offstage: currentIndex != 4, child: const TeachersPage()),
          Offstage(offstage: currentIndex != 5, child: const ProfilePage()),

          // 2. TRANSIENT PAGES (Force fresh API hit)
          if (currentIndex == 1) const ConnectDiscoverPage(),
          if (currentIndex == 3) const KnowledgeHubPage(),
        ],
      ),
      bottomNavigationBar: CustomNavBar(currentIndex: currentIndex),
    );
  }
}
