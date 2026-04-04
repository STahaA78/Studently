import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'community_feed_page.dart';
import 'discover_main.dart';
import 'profile_main.dart';
import 'knowledge_hub_main.dart';
import '../widgets/custom_nav_bar.dart';

class NavigationIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

final navigationIndexProvider = NotifierProvider<NavigationIndexNotifier, int>(() {
  return NavigationIndexNotifier();
});

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);

    return Scaffold(
      body: Stack(
        children: [
          // 1. PERSISTENT PAGES (Preserve scroll/state)
          Offstage(
            offstage: currentIndex != 0,
            child: const CommunityFeedPage(),
          ),
          Offstage(
            offstage: currentIndex != 4,
            child: const ProfilePage(),
          ),

          // 2. TRANSIENT PAGES (Force fresh API hit)
          if (currentIndex == 1) const ConnectDiscoverPage(),
          if (currentIndex == 3) const KnowledgeHubPage(),
        ],
      ),
      bottomNavigationBar: CustomNavBar(currentIndex: currentIndex),
    );
  }
}
