import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/models/notifications.dart';
import 'package:studently/providers/feed_provider.dart';
import 'package:studently/providers/notifications_provider.dart';
import 'package:studently/repositories/chat.dart';
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
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Notifications",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: state.isLoading && state.notifications.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildHeader(
                    unreadCount: state.unreadCount,
                    totalCount: state.notifications.length,
                    onMarkAllRead: controller.markAllAsRead,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: state.notifications.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: controller.refreshFromServer,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              itemCount: state.notifications.length,
                              separatorBuilder: (_, index) =>
                                  SizedBox(key: ValueKey(index), height: 10),
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

  Widget _buildHeader({
    required int unreadCount,
    required int totalCount,
    required VoidCallback onMarkAllRead,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331565C0),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$unreadCount unread",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "$totalCount total notifications",
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: unreadCount > 0 ? onMarkAllRead : null,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: const Color(0xA6FFFFFF),
              backgroundColor: Colors.white.withOpacity(0.16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              "Mark all read",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

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
        String otherUserName = 'Chat';
        if (otherUserId.isNotEmpty) {
          try {
            otherUserName = await ChatRepository().getUserName(otherUserId);
          } catch (_) {}
        }
        if (!mounted) return;
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
          final repo = ref.read(postRepositoryProvider);
          final post = await repo.getPostById(notification.entityId);
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailsPage(postData: post),
            ),
          );
        } catch (_) {}
        return;

      case 'FRIEND_REQUEST':
        if (notification.actorId.isEmpty) return;
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilePage(userId: notification.actorId),
          ),
        );
        return;

      case 'FRIEND_REQUEST_ACCEPTED':
        if (notification.actorId.isEmpty) return;
        if (!mounted) return;
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
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notification.isRead ? Colors.white : const Color(0xFFF1F7FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? const Color(0xFFE6EBF3)
                  : const Color(0xFFBFD9FF),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: style.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(style.icon, color: style.foregroundColor, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.message,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              fontSize: 14.5,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!notification.isRead)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1976D2),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: style.badgeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            style.label,
                            style: TextStyle(
                              color: style.badgeTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatTimeAgo(notification.createdAt),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
          label: "LIKE",
          foregroundColor: Color(0xFFC62828),
          backgroundColor: Color(0xFFFFEBEE),
          badgeColor: Color(0xFFFFEBEE),
          badgeTextColor: Color(0xFFB71C1C),
        );
      case "NEW_COMMENT":
        return const _NotificationVisualStyle(
          icon: Icons.mode_comment_rounded,
          label: "COMMENT",
          foregroundColor: Color(0xFF6A1B9A),
          backgroundColor: Color(0xFFF3E5F5),
          badgeColor: Color(0xFFF3E5F5),
          badgeTextColor: Color(0xFF4A148C),
        );
      case "NEW_MESSAGE":
        return const _NotificationVisualStyle(
          icon: Icons.chat_bubble_rounded,
          label: "MESSAGE",
          foregroundColor: Color(0xFF0277BD),
          backgroundColor: Color(0xFFE1F5FE),
          badgeColor: Color(0xFFE1F5FE),
          badgeTextColor: Color(0xFF01579B),
        );
      case "FRIEND_REQUEST":
        return const _NotificationVisualStyle(
          icon: Icons.person_add_alt_1_rounded,
          label: "REQUEST",
          foregroundColor: Color(0xFF2E7D32),
          backgroundColor: Color(0xFFE8F5E9),
          badgeColor: Color(0xFFE8F5E9),
          badgeTextColor: Color(0xFF1B5E20),
        );
      default:
        return const _NotificationVisualStyle(
          icon: Icons.notifications_rounded,
          label: "UPDATE",
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
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color badgeColor;
  final Color badgeTextColor;

  const _NotificationVisualStyle({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.badgeColor,
    required this.badgeTextColor,
  });
}
