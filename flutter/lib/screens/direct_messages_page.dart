import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:studently/models/chat_model.dart';
import 'package:studently/services/chat_service.dart';
import 'package:studently/screens/chat_page.dart';
import 'package:studently/auth_service.dart';
import 'package:studently/services/socket_service.dart'; // Ensure this is imported

class DirectMessagesPage extends StatefulWidget {
  const DirectMessagesPage({Key? key}) : super(key: key);

  @override
  _DirectMessagesPageState createState() => _DirectMessagesPageState();
}

class _DirectMessagesPageState extends State<DirectMessagesPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  List<ChatConversation> _allConversations = [];
  List<ChatConversation> _filteredConversations = [];
  bool _isLoading = true;

  final Map<String, String> _userNameCache = {};
  StreamSubscription? _socketSubscription; // Added for WebSocket

  @override
  void initState() {
    super.initState();
    _fetchChats();
    _searchController.addListener(_onSearchChanged);
    _initWebSocket(); // Initialize real-time updates
  }

  Future<void> _initWebSocket() async {
    await socketService.connect();
    
    // REAL-TIME: Refresh list (unread counts/last message) on any incoming message
    _socketSubscription = socketService.stream?.listen((event) {
      final payload = jsonDecode(event);
      if (payload['type'] == 'NEW_MESSAGE') {
        _fetchChats(); // Triggers a full list refresh
      }
    });
  }

  @override
  void dispose() {
    _socketSubscription?.cancel(); // Important to prevent memory leaks
    _searchController.dispose();
    super.dispose();
  }

  String _getDisplayName(String id) {
    if (_userNameCache.containsKey(id)) {
      return _userNameCache[id]!;
    }
    _fetchAndCacheName(id);
    return "Loading...";
  }

  Future<void> _fetchAndCacheName(String id) async {
    try {
      final name = await _chatService.getUserName(id);
      if (mounted) {
        setState(() {
          _userNameCache[id] = name;
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch name for $id: $e");
    }
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null || isoString.isEmpty) return "";
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();

      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
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
      final chats = await _chatService.getUserConversations();
      if (mounted) {
        setState(() {
          _allConversations = chats;
          _filteredConversations = chats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching chats: $e");
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    final currentUid = authService.value.currentUser?.uid;

    setState(() {
      _filteredConversations = _allConversations.where((chat) {
        final otherId = chat.participants.firstWhere(
          (id) => id != currentUid,
          orElse: () => "",
        );
        final name = _getDisplayName(otherId).toLowerCase();
        return name.contains(query);
      }).toList();
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
        title: const Text("Messages", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchChats,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredConversations.isEmpty
                    ? Center(child: Text("No messages found", style: TextStyle(color: Colors.grey.shade500)))
                    : ListView.builder(
                        itemCount: _filteredConversations.length,
                        itemBuilder: (context, index) {
                          final chat = _filteredConversations[index];
                          final otherUserId = chat.participants.firstWhere(
                            (id) => id != myId,
                            orElse: () => "Unknown",
                          );

                          final displayName = _getDisplayName(otherUserId);
                          final int unreadCount = chat.unreadCounts[myId] ?? 0;
                          final String lastMsgTime = _formatTimestamp(chat.lastMessage?['timestamp']);

                          return _buildConversationTile(chat, otherUserId, displayName, unreadCount, lastMsgTime);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewChatModel(context),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 4,
        child: const Icon(Icons.add_comment_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(30)),
        child: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: "Search messages...",
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationTile(ChatConversation chat, String otherUserId, String displayName, int unreadCount, String lastMsgTime) {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF1976D2),
              child: Text(
                displayName != "Loading..." && displayName.isNotEmpty ? displayName[0] : "?",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(
                    chat.lastMessage?['text'] ?? "No messages yet",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unreadCount > 0 ? Colors.black87 : Colors.grey.shade600,
                      fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center, // Center the text and badge horizontally
              children: [
                Text(
                  lastMsgTime,
                  style: TextStyle(
                    color: unreadCount > 0 ? const Color(0xFF1976D2) : Colors.grey,
                    fontSize: 11,
                    fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: Color(0xFF1976D2), shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else
                  const SizedBox(height: 28),
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
                        const Text("Start New Chat", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.black),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Search Bar
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15)),
                    child: TextField(
                      onChanged: (value) {
                        setModalState(() {
                          displayList = allFriends
                              .where((f) => f['Name']!.toLowerCase().contains(value.toLowerCase()))
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
                  // Dynamic Friend List using FutureBuilder
                  Expanded(
                    child: FutureBuilder<List<Map<String, String>>>(
                      future: isFirstLoad ? _chatService.getFriendsList() : null,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && isFirstLoad) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (isFirstLoad && snapshot.hasData) {
                          allFriends = snapshot.data!;
                          displayList = List.from(allFriends);
                          isFirstLoad = false;
                        }

                        if (displayList.isEmpty && !isFirstLoad) {
                          return const Center(child: Text("No results found"));
                        }

                        return ListView.builder(
                          itemCount: displayList.length,
                          itemBuilder: (context, index) {
                            final friend = displayList[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 5),
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade50,
                                child: Text(friend['Name']![0].toUpperCase()),
                              ),
                              title: Text(friend['Name']!, style: const TextStyle(fontWeight: FontWeight.w500)),
                              onTap: () async {
                                // Create or Get Conversation
                                final convId = await _chatService.createOrGetConversation(friend['id']!);
                                
                                if (convId != null && context.mounted) {
                                  Navigator.pop(context); // Close modal
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