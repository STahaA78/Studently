import 'package:flutter/material.dart';
import '../screens/community_feed_page.dart';
import '../screens/connect_discover_page.dart';
import '../screens/profile_page.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex;

  const CustomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    const Color blue = Color(0xFF1976D2);

    void _onItemTapped(int index) {
      if (index == currentIndex) return;

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Hub page coming soon!")),
          );
          return;
        case 4:
          destination = const ProfilePage();
          break;
      }

      if (destination != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => destination!),
          (route) => false,
        );
      }
    }

    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: blue,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      onTap: _onItemTapped,
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
