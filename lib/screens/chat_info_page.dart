import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:studently/app_style.dart';
import 'package:studently/models/chat.dart';
import 'package:studently/providers/chat_provider.dart';
import 'package:studently/providers/carpool_provider.dart';
import 'package:studently/logger.dart';

class ChatInfoPage extends ConsumerStatefulWidget {
  final String conversationId;
  final bool isGroup;
  final String? otherUserId; // Only for DM chats

  const ChatInfoPage({
    super.key,
    required this.conversationId,
    required this.isGroup,
    this.otherUserId,
  });

  @override
  ConsumerState<ChatInfoPage> createState() => _ChatInfoPageState();
}

class _ChatInfoPageState extends ConsumerState<ChatInfoPage> {
  @override
  void initState() {
    super.initState();
    // Load chat info when page is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).loadChatInfo(widget.conversationId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final chatInfo = chatState.currentChatInfo;
    final isLoading = chatState.isLoadingChatInfo;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Chat Info'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : chatInfo == null
              ? const Center(child: Text('Failed to load chat info'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      if (widget.isGroup)
                        _buildGroupInfoSection(chatInfo, context)
                      else
                        _buildDmInfoSection(chatInfo, context),
                      const SizedBox(height: 24),
                      _buildActionsSection(context),
                    ],
                  ),
                ),
    );
  }

  /// Build DM chat info section
  Widget _buildDmInfoSection(dynamic chatInfo, BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        // User Avatar
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[300],
            backgroundImage: chatInfo.otherUserPicture != null &&
                    chatInfo.otherUserPicture!.isNotEmpty
                ? CachedNetworkImageProvider(chatInfo.otherUserPicture!)
                : null,
            child: chatInfo.otherUserPicture == null ||
                    chatInfo.otherUserPicture!.isEmpty
                ? Icon(Icons.person, size: 60, color: Colors.grey[600])
                : null,
          ),
        ),
        const SizedBox(height: 20),
        // User Name
        Text(
          chatInfo.otherUserName ?? 'Unknown User',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        // User Details Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (chatInfo.otherUserDepartment != null) ...[
                _buildDetailRow(
                  icon: Icons.school,
                  label: 'Department',
                  value: chatInfo.otherUserDepartment,
                ),
                const SizedBox(height: 12),
              ],
              if (chatInfo.otherUserBatch != null) ...[
                _buildDetailRow(
                  icon: Icons.calendar_today,
                  label: 'Batch',
                  value: chatInfo.otherUserBatch,
                ),
                const SizedBox(height: 12),
              ],
              if (chatInfo.totalMessages != null) ...[
                _buildDetailRow(
                  icon: Icons.message,
                  label: 'Messages',
                  value: chatInfo.totalMessages.toString(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Build group chat info section
  Widget _buildGroupInfoSection(dynamic chatInfo, BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        // Group Avatar
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 60,
            backgroundColor: AppStyle.primaryBlue.withOpacity(0.1),
            child: const Icon(
              Icons.group,
              size: 60,
              color: AppStyle.primaryBlue,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Group Name
        Text(
          chatInfo.groupName ?? 'Group Chat',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // Group Details Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                icon: Icons.people,
                label: 'Members',
                value: '${chatInfo.participantCount ?? 0}',
              ),
              const SizedBox(height: 12),
              if (chatInfo.totalMessages != null) ...[
                _buildDetailRow(
                  icon: Icons.message,
                  label: 'Messages',
                  value: chatInfo.totalMessages.toString(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Participants Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Members',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              if (chatInfo.participants != null && chatInfo.participants!.isNotEmpty)
                ..._buildParticipantsList(chatInfo.participants!)
              else
                const Text('No members to display'),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Build participants list
  List<Widget> _buildParticipantsList(List<dynamic> participants) {
    final displayParticipants =
        participants.length > 5 ? participants.sublist(0, 5) : participants;

    return [
      ...displayParticipants.map((participant) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[300],
                backgroundImage: participant.picture != null &&
                        participant.picture.isNotEmpty
                    ? CachedNetworkImageProvider(participant.picture)
                    : null,
                child: participant.picture == null || participant.picture.isEmpty
                    ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                    : null,
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
                            participant.name ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (participant.role == 'admin')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '👑 Admin',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
      if (participants.length > 5)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '+${participants.length - 5} more members',
            style: TextStyle(
              fontSize: 12,
              color: AppStyle.primaryBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
    ];
  }

  /// Build actions section
  Widget _buildActionsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Clear Chat Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showClearChatDialog(context),
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Clear Chat'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Delete/Leave Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => widget.isGroup
                  ? _showLeaveGroupDialog(context)
                  : _showDeleteChatDialog(context),
              icon: Icon(
                widget.isGroup ? Icons.exit_to_app : Icons.delete,
                size: 20,
              ),
              label: Text(widget.isGroup ? 'Leave Group' : 'Delete Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Build a detail row with icon
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppStyle.primaryBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Show delete chat confirmation dialog
  void _showDeleteChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text(
          'This will delete this conversation from your chat list. '
          'The conversation will still exist for the other person.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChat();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Show leave group confirmation dialog
  void _showLeaveGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text(
          'You will be removed from this group and will no longer receive messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveGroup();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Show clear chat confirmation dialog
  void _showClearChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
          'This will delete all messages from this conversation for you. '
          'Messages will still exist for the other person.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearChat();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child:
                const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Delete chat and navigate back
  Future<void> _deleteChat() async {
    final notifier = ref.read(chatProvider.notifier);
    final success = await notifier.deleteChat(widget.conversationId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat deleted successfully')),
      );
      Navigator.of(context)
        ..pop()
        ..pop(); // Pop info page and chat page
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete chat')),
      );
    }
  }

  /// Leave group and navigate back
  Future<void> _leaveGroup() async {
    final notifier = ref.read(chatProvider.notifier);
    final success = await notifier.leaveGroupChat(widget.conversationId);

    if (success && mounted) {
      // Refresh carpool data since leaving a ride chat frees a seat
      ref.invalidate(carpoolOffersProvider);
      ref.invalidate(myOffersProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Left group successfully')),
      );
      Navigator.of(context)
        ..pop()
        ..pop(); // Pop info page and chat page
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to leave group')),
      );
    }
  }

  /// Clear chat messages
  Future<void> _clearChat() async {
    final notifier = ref.read(chatProvider.notifier);
    final success = await notifier.clearChatMessages(widget.conversationId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat cleared successfully')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to clear chat')),
      );
    }
  }
}
