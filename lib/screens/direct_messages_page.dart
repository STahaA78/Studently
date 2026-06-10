import 'package:studently/app_style.dart';
import 'package:flutter/material.dart';
import 'package:studently/models/chat.dart';
import 'package:studently/screens/chat_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:studently/providers/chat_provider.dart';
import 'package:studently/providers/auth_provider.dart'; // NEW: Added AuthProvider

class DirectMessagesPage extends ConsumerStatefulWidget {
  const DirectMessagesPage({super.key});

  @override
  ConsumerState<DirectMessagesPage> createState() => _DirectMessagesPageState();
}

class _DirectMessagesPageState extends ConsumerState<DirectMessagesPage> {
  final TextEditingController _searchController = TextEditingController();

  List<ChatConversation> _filteredConversations = [];
  String _activeFilter = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // NOTE: Do NOT call fetchConversations() here. The provider's own _init()
    // already fetches on startup. Calling it again here races against any
    // locally-zeroed unread count that loadMessagesForChat just wrote, causing
    // the server's stale count to overwrite our local zero and re-show the badge.
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null || isoString.isEmpty) return "";
    try {
      final String safeTimestamp = isoString.endsWith('Z')
          ? isoString
          : '${isoString}Z';
      final date = DateTime.parse(safeTimestamp).toLocal();
      final now = DateTime.now();
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        final hour = date.hour > 12
            ? date.hour - 12
            : (date.hour == 0 ? 12 : date.hour);
        final period = date.hour >= 12 ? "PM" : "AM";
        final minute = date.minute.toString().padLeft(2, '0');
        return "$hour:$minute $period";
      } else if (now.difference(date).inDays < 2 && date.day != now.day) {
        return "Yesterday";
      } else {
        return "${date.month}/${date.day}";
      }
    } catch (e) {
      return "";
    }
  }

  void _applyFilter(
    List<ChatConversation> allConversations,
    Map<String, String> userNames,
  ) {
    final String? myId = FirebaseAuth.instance.currentUser?.uid;
    final query = _searchController.text.toLowerCase();

    List<ChatConversation> filtered = allConversations.where((chat) {
      if (chat.isGroup) {
        return (chat.title ?? "").toLowerCase().contains(query);
      } else {
        final otherId = chat.participants.firstWhere(
          (id) => id != myId,
          orElse: () => "",
        );
        // Look up the name from the Provider's cache instantly!
        final displayName = userNames[otherId] ?? "Unknown User";
        return displayName.toLowerCase().contains(query);
      }
    }).toList();

    if (_activeFilter == 'Unread') {
      filtered = filtered.where((chat) {
        final unread = chat.unreadCounts[myId] ?? 0;
        return unread > 0;
      }).toList();
    } else if (_activeFilter == 'Groups') {
      filtered = filtered.where((chat) => chat.isGroup).toList();
    }

    _filteredConversations = filtered;
  }

  void _onSearchChanged() => setState(() {});

  /// Returns a human-readable preview string for the last message.
  /// Falls back to a filename (or generic label) when the message text is empty
  /// but attachments are present — e.g. photo/file/voice-note sends.
  String _buildLastMessagePreview(Map<String, dynamic>? lastMessage) {
    if (lastMessage == null) return "No messages yet";

    final text = (lastMessage['text'] as String?)?.trim() ?? '';
    if (text.isNotEmpty) return text;

    // Text is empty — check attachments
    final attachments = lastMessage['attachments'];
    if (attachments is List && attachments.isNotEmpty) {
      final url = attachments.first.toString();
      final cleanPath = url.split('?').first.toLowerCase();

      if (cleanPath.endsWith('.m4a') ||
          cleanPath.endsWith('.mp3') ||
          cleanPath.endsWith('.aac') ||
          cleanPath.endsWith('.wav')) {
        return "🎤 Voice message";
      }
      if (cleanPath.endsWith('.jpg') ||
          cleanPath.endsWith('.jpeg') ||
          cleanPath.endsWith('.png') ||
          cleanPath.endsWith('.gif') ||
          cleanPath.endsWith('.webp') ||
          cleanPath.endsWith('.heic')) {
        return "📷 Photo";
      }
      if (cleanPath.endsWith('.mp4') ||
          cleanPath.endsWith('.mov') ||
          cleanPath.endsWith('.avi') ||
          cleanPath.endsWith('.mkv')) {
        return "🎥 Video";
      }

      // Generic file — try to extract the original filename
      final decodedUrl = Uri.decodeFull(url);
      final fullName = decodedUrl.split('/').last.split('?').first;
      final lastDotIndex = fullName.lastIndexOf('.');
      if (lastDotIndex != -1) {
        final namePart = fullName.substring(0, lastDotIndex);
        final extPart = fullName.substring(lastDotIndex);
        // Strip the 9-char backend suffix (e.g. "-a1b2c3d4e")
        if (namePart.length > 9 && namePart[namePart.length - 9] == '-') {
          return "📎 ${namePart.substring(0, namePart.length - 9)}$extPart";
        }
        return "📎 $fullName";
      }
      return "📎 Attachment";
    }

    return "No messages yet";
  }

  void _setFilter(String filter) {
    setState(() {
      _activeFilter = filter;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the global provider state
    final chatState = ref.watch(chatProvider);

    // Apply filters passing the conversations AND the fast name cache
    _applyFilter(chatState.conversations, chatState.userNames);

    final String? myId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Messages",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: AppStyle.appBarTitleSize,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _showNewChatModel(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F0FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: AppStyle.primaryBlue,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: chatState.isBootstrapping
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppStyle.primaryBlue,
                    ),
                  )
                : _filteredConversations.isEmpty
                ? Center(
                    child: Text(
                      chatState.conversations.isEmpty
                          ? "No chats" // Fallback text
                          : "No messages match your search",
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredConversations.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 76,
                      endIndent: 16,
                      color: Colors.grey.shade200,
                    ),
                    itemBuilder: (context, index) {
                      final chat = _filteredConversations[index];
                      final bool isGroup = chat.isGroup;
                      final String otherUserId = isGroup
                          ? "GROUP"
                          : chat.participants.firstWhere(
                              (id) => id != myId,
                              orElse: () => "Unknown",
                            );

                      // Instant name and pic lookup from the Provider cache!
                      final String displayName = isGroup
                          ? (chat.title ?? "Group Chat")
                          : (chatState.userNames[otherUserId] ??
                                "Unknown User");
                      final String userPic = isGroup
                          ? ""
                          : (chatState.userPics[otherUserId] ?? "");

                      final int unreadCount = chat.unreadCounts[myId] ?? 0;
                      final String lastMsgTime = _formatTimestamp(
                        chat.lastMessage?['timestamp'],
                      );

                      return _buildConversationTile(
                        chat,
                        otherUserId,
                        displayName,
                        unreadCount,
                        lastMsgTime,
                        isGroup,
                        userPic,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: AppStyle.searchDecoration("Search messages..."),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: ['All', 'Unread', 'Groups'].map((label) {
          final bool isActive = _activeFilter == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _setFilter(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isActive ? AppStyle.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? AppStyle.primaryBlue
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConversationTile(
    ChatConversation chat,
    String otherUserId,
    String displayName,
    int unreadCount,
    String lastMsgTime,
    bool isGroup,
    String userPic,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversationId: chat.id,
              otherUserId: otherUserId,
              otherUserName: displayName,
            ),
          ),
        ).then((_) {
          // NEW: Safely clear the active chat the moment you return to this screen!
          ref.read(chatProvider.notifier).clearActiveChat();
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: isGroup
                  ? Colors.orange.shade400
                  : AppStyle.primaryBlue,
              backgroundImage: userPic.isNotEmpty
                  ? CachedNetworkImageProvider(userPic)
                  : null,
              child: isGroup
                  ? const Icon(Icons.groups, color: Colors.white, size: 26)
                  : (userPic.isEmpty
                        ? Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : "?",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: unreadCount > 0
                          ? FontWeight.w700
                          : FontWeight.w600,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _buildLastMessagePreview(chat.lastMessage),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unreadCount > 0
                          ? Colors.black87
                          : Colors.grey.shade500,
                      fontWeight: unreadCount > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  lastMsgTime,
                  style: TextStyle(
                    color: unreadCount > 0
                        ? AppStyle.primaryBlue
                        : Colors.grey.shade400,
                    fontSize: 11,
                    fontWeight: unreadCount > 0
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 5),
                if (unreadCount > 0)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppStyle.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? "99+" : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNewChatModel(BuildContext context) {
    final outerContext = context;
    final authNotifier = ref.read(authProvider.notifier);

    // Snapshot the cached list — may be empty if the background fetch hasn't
    // finished yet. The StatefulBuilder below will trigger a fresh fetch and
    // call setModalState() when it arrives so the list updates live.
    List<Map<String, String>> allFriends = List.from(authNotifier.friendsList);
    List<Map<String, String>> displayList = List.from(allFriends);
    bool isFetchingFriends = false;
    bool hasAttemptedFetch = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // If the list is empty and we haven't started a fetch yet, kick one
            // off now and refresh the modal when it resolves.
            if (allFriends.isEmpty &&
                !isFetchingFriends &&
                !hasAttemptedFetch) {
              isFetchingFriends = true;
              hasAttemptedFetch = true;
              authNotifier.fetchFriendsList().then((_) {
                if (outerContext.mounted) {
                  setModalState(() {
                    allFriends = List.from(authNotifier.friendsList);
                    displayList = List.from(allFriends);
                    isFetchingFriends = false;
                  });
                }
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Start New Chat",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black),
                          onPressed: () => Navigator.pop(outerContext),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: TextField(
                      onChanged: (value) {
                        setModalState(() {
                          displayList = allFriends
                              .where(
                                (f) => f['Name']!.toLowerCase().contains(
                                  value.toLowerCase(),
                                ),
                              )
                              .toList();
                        });
                      },
                      decoration: AppStyle.searchDecoration(
                        "Search friends...",
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: isFetchingFriends
                        ? const Center(child: CircularProgressIndicator())
                        : displayList.isEmpty
                        ? Center(
                            child: Text(
                              allFriends.isEmpty
                                  ? "No friends"
                                  : "No results found",
                            ),
                          )
                        : ListView.builder(
                            itemCount: displayList.length,
                            itemBuilder: (context, index) {
                              final friend = displayList[index];
                              final friendPic = friend['picture'] ?? "";
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFE8F0FE),
                                  backgroundImage: friendPic.isNotEmpty
                                      ? CachedNetworkImageProvider(friendPic)
                                      : null,
                                  child: friendPic.isEmpty
                                      ? Text(
                                          friend['Name']![0].toUpperCase(),
                                          style: const TextStyle(
                                            color: AppStyle.primaryBlue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  friend['Name']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                onTap: () async {
                                  // 3. Call the Provider to smartly route or create the chat!
                                  final convId = await ref
                                      .read(chatProvider.notifier)
                                      .createOrGetConversation(friend['id']!);

                                  if (convId != null && outerContext.mounted) {
                                    Navigator.pop(outerContext);
                                    Navigator.push(
                                      outerContext,
                                      MaterialPageRoute(
                                        builder: (_) => ChatPage(
                                          conversationId: convId,
                                          otherUserId: friend['id']!,
                                          otherUserName: friend['Name']!,
                                        ),
                                      ),
                                    ).then((_) {
                                      // Safely clear active chat when returning
                                      ref
                                          .read(chatProvider.notifier)
                                          .clearActiveChat();
                                    });
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
