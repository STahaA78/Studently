import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'community_feed_page.dart';
import 'discover_main.dart';
import 'profile_main.dart';
import 'knowledge_hub_main.dart';
import '../widgets/custom_nav_bar.dart';

// Use a Notifier for the navigation index (Modern Riverpod 3.0 style)
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

    // List of screens for the bottom navigation
    // IndexedStack keeps all of these "alive" in the background
    final List<Widget> screens = [
      const CommunityFeedPage(),
      const ConnectDiscoverPage(),
      const SizedBox.shrink(), // Placeholder for the "Add Post" button
      const KnowledgeHubPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: CustomNavBar(currentIndex: currentIndex),
    );
  }
}
