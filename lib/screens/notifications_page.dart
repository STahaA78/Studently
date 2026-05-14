import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/models/notifications.dart';
import 'package:studently/models/post.dart';
import 'package:studently/providers/feed_provider.dart';
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
    final sections = _groupNotifications(state.notifications);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Inbox",
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
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
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              itemCount: sections.length,
                              itemBuilder: (context, sectionIndex) {
                                final section = sections[sectionIndex];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          2,
                                          2,
                                          2,
                                          8,
                                        ),
                                        child: Text(
                                          section.title,
                                          style: const TextStyle(
                                            color: Color(0xFF4B5563),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ),
                                      ...section.items.map(
                                        (notification) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: _NotificationCard(
                                            notification: notification,
                                            onTap: () => _handleNotificationTap(
                                              context: context,
                                              notification: notification,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
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
    final bool hasUnread = unreadCount > 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F4C97), Color(0xFF2D7CCF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330F4C97),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasUnread ? "$unreadCount unread" : "All caught up",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "$totalCount notifications in your inbox",
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
            onPressed: hasUnread ? onMarkAllRead : null,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: const Color(0xA6FFFFFF),
              backgroundColor: Colors.white.withValues(alpha: 0.18),
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
            targetPost = currentFeed.firstWhere((p) => p.id == notification.entityId);
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
              const SnackBar(content: Text("Unable to load post. It may have been deleted.")),
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
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            color: notification.isRead ? Colors.white : const Color(0xFFF1F7FF),
            borderRadius: BorderRadius.circular(18),
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
                  gradient: LinearGradient(
                    colors: [
                      style.backgroundColor,
                      style.backgroundColor.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatTimeAgo(notification.createdAt),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: Color(0xFF9CA3AF),
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

class _NotificationSection {
  final String title;
  final List<AppNotification> items;

  const _NotificationSection({
    required this.title,
    required this.items,
  });
}

List<_NotificationSection> _groupNotifications(List<AppNotification> items) {
  final now = DateTime.now();
  final today = <AppNotification>[];
  final yesterday = <AppNotification>[];
  final earlier = <AppNotification>[];

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  final nowDate = DateTime(now.year, now.month, now.day);
  final yesterdayDate = nowDate.subtract(const Duration(days: 1));

  for (final item in items) {
    final itemDate = DateTime(
      item.createdAt.year,
      item.createdAt.month,
      item.createdAt.day,
    );
    if (isSameDay(itemDate, nowDate)) {
      today.add(item);
    } else if (isSameDay(itemDate, yesterdayDate)) {
      yesterday.add(item);
    } else {
      earlier.add(item);
    }
  }

  final sections = <_NotificationSection>[];
  if (today.isNotEmpty) {
    sections.add(_NotificationSection(
      title: "TODAY",
      items: today,
    ));
  }
  if (yesterday.isNotEmpty) {
    sections.add(_NotificationSection(
      title: "YESTERDAY",
      items: yesterday,
    ));
  }
  if (earlier.isNotEmpty) {
    sections.add(_NotificationSection(
      title: "EARLIER",
      items: earlier,
    ));
  }
  return sections;
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