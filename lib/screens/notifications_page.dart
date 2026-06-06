import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/app_style.dart';
import 'package:studently/models/notifications.dart';
import 'package:studently/models/post.dart';
import 'package:studently/providers/feed_provider.dart';
import 'package:studently/providers/chat_provider.dart';
import 'package:studently/providers/notifications_provider.dart';
// import 'package:studently/repositories/chat.dart';
import 'package:studently/screens/chat_page.dart';
import 'package:studently/screens/post_details_page.dart';
import 'package:studently/screens/profile_main.dart';
import 'package:studently/utils/time_ago.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).refreshFromServer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);
    final controller = ref.read(notificationProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: AppStyle.appBarTitleSize,
          ),
        ),
      ),
      body: SafeArea(
        child: state.isLoading && state.notifications.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: state.notifications.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: controller.refreshFromServer,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: state.notifications.length,
                              separatorBuilder: (_, _) => Divider(
                                color: const Color(0xFFE6EBF3),
                                height: 1,
                              ),
                              itemBuilder: (context, index) {
                                final notification = state.notifications[index];
                                return _NotificationCard(
                                  notification: notification,
                                  onTap: () => _handleNotificationTap(
                                    context: context,
                                    notification: notification,
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  // Widget _buildHeader({
  //   required int unreadCount,
  //   required int totalCount,
  //   required VoidCallback onMarkAllRead,
  // }) {
  //   final bool hasUnread = unreadCount > 0;
  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 16),
  //     padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
  //     decoration: BoxDecoration(
  //       color: const Color(0xFF1976D2),
  //       borderRadius: BorderRadius.circular(20),
  //       boxShadow: const [
  //         BoxShadow(
  //           color: Color(0x330F4C97),
  //           blurRadius: 18,
  //           offset: Offset(0, 10),
  //         ),
  //       ],
  //     ),
  //     child: Row(
  //       children: [
  //         Container(
  //           width: 48,
  //           height: 48,
  //           decoration: BoxDecoration(
  //             color: Colors.white.withValues(alpha: 0.22),
  //             borderRadius: BorderRadius.circular(14),
  //           ),
  //           child: const Icon(
  //             Icons.notifications_none_rounded,
  //             color: Colors.white,
  //           ),
  //         ),
  //         const SizedBox(width: 12),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 hasUnread ? "$unreadCount unread" : "All caught up",
  //                 style: const TextStyle(
  //                   color: Colors.white,
  //                   fontSize: 18,
  //                   fontWeight: FontWeight.w700,
  //                 ),
  //               ),
  //               const SizedBox(height: 2),
  //               Text(
  //                 "$totalCount notifications in your inbox",
  //                 style: const TextStyle(
  //                   color: Color(0xE6FFFFFF),
  //                   fontSize: 13,
  //                   fontWeight: FontWeight.w500,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //         TextButton(
  //           onPressed: hasUnread ? onMarkAllRead : null,
  //           style: TextButton.styleFrom(
  //             foregroundColor: Colors.white,
  //             disabledForegroundColor: const Color(0xA6FFFFFF),
  //             backgroundColor: Colors.white.withValues(alpha: 0.18),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  //           ),
  //           child: const Text(
  //             "Mark all read",
  //             style: TextStyle(fontWeight: FontWeight.w600),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildEmpty() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE3E9F4)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 40,
              color: Color(0xFF607D8B),
            ),
            SizedBox(height: 10),
            Text(
              "No notifications yet",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              "When activity happens, updates will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleNotificationTap({
    required BuildContext context,
    required AppNotification notification,
  }) async {
    final controller = ref.read(notificationProvider.notifier);
    await controller.markAsRead(notification.id);

    switch (notification.type) {
      case 'NEW_MESSAGE':
        if (notification.entityId.isEmpty) return;
        final otherUserId = notification.actorId;
        final chatState = ref.read(chatProvider);
        final otherUserName = chatState.userNames[otherUserId] ?? 'Chat';
        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversationId: notification.entityId,
              otherUserId: otherUserId.isNotEmpty ? otherUserId : 'UNKNOWN',
              otherUserName: otherUserName,
            ),
          ),
        );
        return;

      case 'POST_LIKE':
      case 'NEW_COMMENT':
        if (notification.entityId.isEmpty) return;
        try {
          // 1. Try to find the post in the local feed cache first
          final currentFeed = ref.read(feedProvider).value ?? [];
          Post? targetPost;
          try {
            targetPost = currentFeed.firstWhere(
              (p) => p.id == notification.entityId,
            );
          } catch (_) {}

          // 2. Fallback to the API if not found locally
          if (targetPost == null) {
            final repo = ref.read(postRepositoryProvider);
            targetPost = await repo.getPostById(notification.entityId);
          }

          if (!context.mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailsPage(postData: targetPost!),
            ),
          );
        } catch (e) {
          // Fallback UI indication instead of failing silently on 500 error
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Unable to load post. It may have been deleted."),
              ),
            );
          }
        }
        return;

      case 'FRIEND_REQUEST':
        if (notification.actorId.isEmpty) return;
        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilePage(userId: notification.actorId),
          ),
        );
        return;

      case 'FRIEND_REQUEST_ACCEPTED':
        if (notification.actorId.isEmpty) return;
        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilePage(userId: notification.actorId),
          ),
        );
        return;

      default:
        return;
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = _styleForType(notification.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      style.backgroundColor,
                      style.backgroundColor.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(style.icon, color: style.foregroundColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatTimeAgo(notification.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF9CA3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _NotificationVisualStyle _styleForType(String type) {
    switch (type) {
      case "POST_LIKE":
        return const _NotificationVisualStyle(
          icon: Icons.favorite_rounded,
          foregroundColor: Color(0xFFC62828),
          backgroundColor: Color(0xFFFFEBEE),
          badgeColor: Color(0xFFFFEBEE),
          badgeTextColor: Color(0xFFB71C1C),
        );
      case "NEW_COMMENT":
        return const _NotificationVisualStyle(
          icon: Icons.mode_comment_rounded,
          foregroundColor: Color(0xFF6A1B9A),
          backgroundColor: Color(0xFFF3E5F5),
          badgeColor: Color(0xFFF3E5F5),
          badgeTextColor: Color(0xFF4A148C),
        );
      case "NEW_MESSAGE":
        return const _NotificationVisualStyle(
          icon: Icons.chat_bubble_rounded,
          foregroundColor: Color(0xFF0277BD),
          backgroundColor: Color(0xFFE1F5FE),
          badgeColor: Color(0xFFE1F5FE),
          badgeTextColor: Color(0xFF01579B),
        );
      case "FRIEND_REQUEST":
        return const _NotificationVisualStyle(
          icon: Icons.person_add_alt_1_rounded,
          foregroundColor: Color(0xFF2E7D32),
          backgroundColor: Color(0xFFE8F5E9),
          badgeColor: Color(0xFFE8F5E9),
          badgeTextColor: Color(0xFF1B5E20),
        );
      default:
        return const _NotificationVisualStyle(
          icon: Icons.notifications_rounded,
          foregroundColor: Color(0xFF1565C0),
          backgroundColor: Color(0xFFE3F2FD),
          badgeColor: Color(0xFFE3F2FD),
          badgeTextColor: Color(0xFF0D47A1),
        );
    }
  }
}

class _NotificationVisualStyle {
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color badgeColor;
  final Color badgeTextColor;

  const _NotificationVisualStyle({
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.badgeColor,
    required this.badgeTextColor,
  });
}
