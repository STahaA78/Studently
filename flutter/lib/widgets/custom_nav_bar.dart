import 'package:flutter/material.dart';
import '../screens/community_feed_page.dart';
import '../screens/connect_discover_page.dart';
import '../screens/profile_page.dart';
import '../screens/knowledge_hub_page.dart';
import '../screens/create_post_page.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex;

  const CustomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    const Color blue = Color(0xFF1976D2);

    void _navigateTo(Widget destination) {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => destination,
          transitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
        (route) => false,
      );
    }

    void _onItemTapped(int index) async {
      Widget? destination;

      switch (index) {
        case 0:
          destination = const CommunityFeedPage();
          break;

        case 1:
          destination = const ConnectDiscoverPage();
          break;

        case 2:

          final created = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreatePostPage(),
            ),
          );

          if (created == true) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const CommunityFeedPage(),
              ),
              (route) => false,
            );
          }

          return;

        case 3:
          destination = const KnowledgeHubPage();
          break;

        case 4:
          destination = const ProfilePage();
          break;
      }

      if (destination == null) return;

      _navigateTo(destination);
    }

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: blue,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_filled),
          label: "Feed",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_alt),
          label: "Connect",
        ),
        BottomNavigationBarItem(
          icon: CircleAvatar(
            radius: 15,
            backgroundColor: blue,
            child: Icon(Icons.add, color: Colors.white, size: 20),
          ),
          label: "Post",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.grid_view),
          label: "Hub",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: "Profile",
        ),
      ],
    );
  }
}