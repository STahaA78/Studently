import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NotificationBadgeIcon extends StatelessWidget {
  final int unreadCount;
  final IconData? icon;
  final String? svgAssetPath;
  final VoidCallback onPressed;
  final Color iconColor;
  final double iconSize;

  const NotificationBadgeIcon({
    super.key,
    required this.unreadCount,
    required this.onPressed,
    this.icon,
    this.svgAssetPath,
    this.iconColor = Colors.grey,
    this.iconSize = 25,
  }) : assert(icon != null || svgAssetPath != null, 'Either icon or svgAssetPath must be provided');

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          svgAssetPath != null
              ? SvgPicture.asset(
                  svgAssetPath!,
                  height: iconSize,
                  width: iconSize,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                )
              : Icon(icon, color: iconColor, size: iconSize),
          if (unreadCount > 0)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
                child: Text(
                  unreadCount > 99 ? "99+" : "$unreadCount",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
