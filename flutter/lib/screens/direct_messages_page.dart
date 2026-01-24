import 'package:flutter/material.dart';
import 'package:studently/models/chat_model.dart';
import 'package:studently/services/chat_service.dart';
import 'package:studently/screens/chat_page.dart';

class DirectMessagesPage extends StatefulWidget {
  const DirectMessagesPage({Key? key}) : super(key: key);

  @override
  _DirectMessagesPageState createState() => _DirectMessagesPageState();
}

class _DirectMessagesPageState extends State<DirectMessagesPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  final String currentUserId = "6974b9e5ceb466b7c81432aa";

  List<ChatConversation> _allConversations = [];
  List<ChatConversation> _filteredConversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchChats();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getNameForId(String id) {
    if (id == "693ab70c8fd1bcb42caf523e") return "Abdul Moiz Pasha";
    if (id == "693abdc3a724df74ca6a7878") return "Ameer Hamza";
    return "Student User";
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null || isoString.isEmpty) return "";
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();

      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        final hour = date.hour > 12 ? date.hour - 12 : date.hour;
        final period = date.hour >= 12 ? "PM" : "AM";
        final minute = date.minute.toString().padLeft(2, '0');
        return "$hour:$minute $period";
      } else if (now.difference(date).inDays < 1) {
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
      final chats = await _chatService.getUserConversations(currentUserId);
      if (mounted) {
        setState(() {
          _allConversations = chats;
          _filteredConversations = chats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Error fetching chats: $e");
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredConversations = _allConversations.where((chat) {
        final otherId = chat.participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => "",
        );
        final name = _getNameForId(otherId).toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchChats,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
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
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredConversations.isEmpty
                    ? Center(
                        child: Text("No messages found",
                            style: TextStyle(color: Colors.grey.shade500)))
                    : ListView.builder(
                        itemCount: _filteredConversations.length,
                        itemBuilder: (context, index) {
                          final chat = _filteredConversations[index];
                          
                          final otherUserId = chat.participants.firstWhere(
                            (id) => id != currentUserId,
                            orElse: () => "Unknown",
                          );

                          final displayName = _getNameForId(otherUserId);
                          final int unreadCount = chat.unreadCounts[currentUserId] ?? 0;
                          final String lastMsgTime = _formatTimestamp(chat.lastMessage?['timestamp']);

                          // Custom Row Layout instead of ListTile to prevent overflow
                          return InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatPage(
                                    conversationId: chat.id,
                                    currentUserId: currentUserId,
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
                                crossAxisAlignment: CrossAxisAlignment.start, // Align to top
                                children: [
                                  // 1. Avatar
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: const Color(0xFF1976D2),
                                    child: Text(
                                      displayName.isNotEmpty ? displayName[0] : "?",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // 2. Name & Message (Expanded to take available space)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          chat.lastMessage?['text'] ?? "No messages yet",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: unreadCount > 0 
                                                ? Colors.black87 
                                                : Colors.grey.shade600,
                                            fontWeight: unreadCount > 0 
                                                ? FontWeight.w600 
                                                : FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 8),

                                  // 3. Time & Badge (Fixed width container if needed, or just column)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        lastMsgTime,
                                        style: TextStyle(
                                          color: unreadCount > 0
                                              ? const Color(0xFF1976D2)
                                              : Colors.grey,
                                          fontSize: 12,
                                          fontWeight: unreadCount > 0
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (unreadCount > 0)
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF1976D2),
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 20,
                                            minHeight: 20,
                                          ),
                                          child: Center(
                                            child: Text(
                                              unreadCount.toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        )
                                      else
                                        // Invisible spacer to keep alignment stable
                                        const SizedBox(height: 20), 
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}