import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/screens/main_screen.dart';
import 'package:studently/screens/create_post_page.dart';

class CustomNavBar extends ConsumerWidget {
  final int currentIndex;

  const CustomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const Color blue = Color(0xFF1976D2);

    void onItemTapped(int index) async {
      if (index == 2) {
        final created = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CreatePostPage(),
          ),
        );

        if (created == true) {
          ref.read(navigationIndexProvider.notifier).setIndex(0);
        }
        return;
      }

      ref.read(navigationIndexProvider.notifier).setIndex(index);
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
