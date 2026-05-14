import 'package:studently/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:studently/screens/community_feed_page.dart';
import 'package:studently/screens/discover_main.dart';
import 'package:studently/screens/profile_main.dart';
import 'package:studently/screens/knowledge_hub_main.dart';
import 'package:studently/screens/create_post_page.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex;

  const CustomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    const Color blue = AppStyle.primaryBlue;

    void onItemTapped(int index) async {
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
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostPage()),
          );

          if (created == true) {
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              PageRouteBuilder(
                pageBuilder: (_, _, _) => const CommunityFeedPage(),
                transitionDuration: const Duration(milliseconds: 200),
                transitionsBuilder: (_, animation, _, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
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

      if (destination != null) {
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => destination!,
            transitionDuration: const Duration(milliseconds: 200),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
          (route) => false,
        );
      }
    }

    // Helper function to get SVG asset path based on selection state
    String getSvgAssetPath(int index, bool isSelected) {
      final paths = [
        ('assets/images/feed-outlined.svg', 'assets/images/feed-filled.svg'),
        (
          'assets/images/connect-outlined.svg',
          'assets/images/connect-filled.svg',
        ),
        ('assets/images/post.svg', 'assets/images/post.svg'),
        (
          'assets/images/knowledgehub-outlined.svg',
          'assets/images/knowledgehub-filled.svg',
        ),
        (
          'assets/images/profile-outlined.svg',
          'assets/images/profile-filled.svg',
        ),
      ];
      return isSelected ? paths[index].$2 : paths[index].$1;
    }

    return SafeArea(
      top: false,
      child: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: currentIndex,
        onTap: onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: false,
        showSelectedLabels: false,
        items: List.generate(5, (index) {
          final assetPath = getSvgAssetPath(index, currentIndex == index);
          return BottomNavigationBarItem(
            icon: SvgPicture.asset(
              assetPath,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                currentIndex == index ? blue : Colors.grey,
                BlendMode.srcIn,
              ),
            ),
            label: "",
          );
        }),
      ),
    );
  }
}
