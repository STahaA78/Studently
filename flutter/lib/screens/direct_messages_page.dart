import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:studently/models/chat.dart';
import 'package:studently/repositories/chat.dart';
import 'package:studently/screens/chat_page.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/services/socket.dart';
import 'package:studently/logger.dart';

class DirectMessagesPage extends StatefulWidget {
  const DirectMessagesPage({super.key});

  @override
  State<DirectMessagesPage> createState() => _DirectMessagesPageState();
}

class _DirectMessagesPageState extends State<DirectMessagesPage>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();

  List<ChatConversation> _allConversations = [];
  List<ChatConversation> _filteredConversations = [];
  bool _isLoading = true;
  String _activeFilter = 'All'; // NEW: track active filter chip

  final Map<String, String> _userNameCache = {};
  StreamSubscription? _socketSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchChats();
    _searchController.addListener(_onSearchChanged);
    _initWebSocket();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      logger.i("[DirectMessagesPage] App Resumed - Reconnecting WebSocket");
      socketService.connect();
    } else if (state == AppLifecycleState.paused) {
      logger.i("[DirectMessagesPage] App Paused - Disconnecting WebSocket");
      socketService.disconnect();
    }
  }

  Future<void> _initWebSocket() async {
    await socketService.connect();
    _socketSubscription ??= socketService.stream?.listen((event) {
      final payload = jsonDecode(event);
      if (payload['type'] == 'NEW_MESSAGE') {
        _fetchChats();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    socketService.disconnect();
    _socketSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _getDisplayName(String id) {
    if (_userNameCache.containsKey(id)) return _userNameCache[id]!;
    _fetchAndCacheName(id);
    return "Loading...";
  }

  Future<void> _fetchAndCacheName(String id) async {
    try {
      final name = await ChatRepository().getUserName(id);
      if (mounted) setState(() => _userNameCache[id] = name);
    } catch (e) {
      debugPrint("Failed to fetch name for $id: $e");
    }
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null || isoString.isEmpty) return "";
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        final hour =
            date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
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

  Future<void> _fetchChats() async {
    try {
      final chats = await ChatRepository().getUserConversations();
      if (mounted) {
        setState(() {
          _allConversations = chats;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching chats: $e");
    }
  }

  void _applyFilter() {
    final String? myId = authService.value.currentUser?.uid;
    final query = _searchController.text.toLowerCase();

    List<ChatConversation> filtered = _allConversations.where((chat) {
      if (chat.isGroup) {
        return (chat.title ?? "").toLowerCase().contains(query);
      } else {
        final otherId = chat.participants.firstWhere(
          (id) => id != myId,
          orElse: () => "",
        );
        return _getDisplayName(otherId).toLowerCase().contains(query);
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

  void _onSearchChanged() => setState(() => _applyFilter());

  void _setFilter(String filter) {
    setState(() {
      _activeFilter = filter;
      _applyFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? myId = authService.value.currentUser?.uid;

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
            fontSize: 20,
          ),
        ),
        actions: [
          // NEW: Replaced refresh + dots with a single "new chat" icon button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _showNewChatModel(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF1976D2),
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredConversations.isEmpty
                    ? Center(
                        child: Text(
                          "No messages found",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredConversations.length,
                        separatorBuilder: (_, __) => Divider(
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
                          final String displayName = isGroup
                              ? (chat.title ?? "Group Chat")
                              : _getDisplayName(otherUserId);
                          final int unreadCount =
                              chat.unreadCounts[myId] ?? 0;
                          final String lastMsgTime =
                              _formatTimestamp(chat.lastMessage?['timestamp']);

                          return _buildConversationTile(
                            chat,
                            otherUserId,
                            displayName,
                            unreadCount,
                            lastMsgTime,
                            isGroup,
                          );
                        },
                      ),
          ),
        ],
      ),
      // FAB removed from here — new chat is now in the AppBar action
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: "Search messages...",
            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  // NEW: Filter chips row (All / Unread / Groups)
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF1976D2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF1976D2)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
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
  ) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversationId: chat.id,
              otherUserId: otherUserId,
              otherUserName: displayName,
            ),
          ),
        );
        _fetchChats();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor:
                  isGroup ? Colors.orange.shade400 : const Color(0xFF1976D2),
              child: isGroup
                  ? const Icon(Icons.groups, color: Colors.white, size: 26)
                  : Text(
                      displayName != "Loading..." && displayName.isNotEmpty
                          ? displayName[0]
                          : "?",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
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
                  ),
                  const SizedBox(height: 3),
                  Text(
                    chat.lastMessage?['text'] ?? "No messages yet",
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
                        ? const Color(0xFF1976D2)
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
                      color: Color(0xFF1976D2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount.toString(),
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
    List<Map<String, String>> allFriends = [];
    List<Map<String, String>> displayList = [];
    bool isFirstLoad = true;

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
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setModalState(() {
                          displayList = allFriends
                              .where((f) => f['Name']!
                                  .toLowerCase()
                                  .contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: "Search friends...",
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: FutureBuilder<List<Map<String, String>>>(
                      future: isFirstLoad
                          ? ChatRepository().getFriendsList()
                          : null,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            isFirstLoad) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (isFirstLoad && snapshot.hasData) {
                          allFriends = snapshot.data!;
                          displayList = List.from(allFriends);
                          isFirstLoad = false;
                        }
                        if (displayList.isEmpty && !isFirstLoad) {
                          return const Center(
                              child: Text("No results found"));
                        }
                        return ListView.builder(
                          itemCount: displayList.length,
                          itemBuilder: (context, index) {
                            final friend = displayList[index];
                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 5),
                             leading: CircleAvatar(
                                backgroundColor: const Color(0xFFE8F0FE),
                                child: Text(
                                  friend['Name']![0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF1976D2), 
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                friend['Name']!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              onTap: () async {
                                final convId = await ChatRepository()
                                    .createOrGetConversation(friend['id']!);
                                if (convId != null && context.mounted) {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatPage(
                                        conversationId: convId,
                                        otherUserId: friend['id']!,
                                        otherUserName: friend['Name']!,
                                      ),
                                    ),
                                  ).then((_) => _fetchChats());
                                }
                              },
                            );
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