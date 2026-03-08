import 'package:flutter/material.dart';
import 'package:studently/screens/community_feed_page.dart';
import 'package:studently/screens/connect_discover_page.dart';
import 'package:studently/screens/profile_page.dart';
import 'package:studently/screens/knowledge_hub_main.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex;

  const CustomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    const Color blue = Color(0xFF1976D2);

    void onItemTapped(int index) {
      if (index == currentIndex) return; // stay on same page

      // Define the correct destination for each tab
      Widget? destination;
      switch (index) {
        case 0:
          destination = const CommunityFeedPage();
          break;
        case 1:
          destination = const ConnectDiscoverPage();
          break;
        case 2:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Create post coming soon!")),
          );
          return;
        case 3:
          destination = const KnowledgeHubPage(); // ✅ HUB FIX
          break;
        case 4:
          destination = const ProfilePage();
          break;
      }

      if (destination != null) {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => destination!,
            transitionDuration: const Duration(milliseconds: 200),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
          (route) => false, // Remove all previous routes
        );
      }
    }

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onItemTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: blue,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Feed"),
        BottomNavigationBarItem(icon: Icon(Icons.people_alt), label: "Connect"),
        BottomNavigationBarItem(
          icon: CircleAvatar(
            radius: 15,
            backgroundColor: blue,
            child: Icon(Icons.add, color: Colors.white, size: 20),
          ),
          label: "Post",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "Hub"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }
}
