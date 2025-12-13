import 'package:flutter/material.dart';
import 'chat_page.dart'; // ✅ Import the chat page

class DirectMessagesPage extends StatefulWidget {
  const DirectMessagesPage({super.key});

  @override
  State<DirectMessagesPage> createState() => _DirectMessagesPageState();
}

class _DirectMessagesPageState extends State<DirectMessagesPage> {
  final Color blue = const Color(0xFF1976D2);
  final TextEditingController _searchController = TextEditingController();

  // Sample conversation list
  final List<Map<String, dynamic>> conversations = [
    {
      "name": "Moiz Pasha",
      "message": "Will you come today?",
      "time": "Yesterday",
      "unread": 2,
      "isGroup": false,
    },
    {
      "name": "Database Systems",
      "message": "Remember to review Chapter 5 for the quiz!",
      "time": "Sat",
      "unread": 3,
      "isGroup": true,
    },
    {
      "name": "AI Study Group",
      "message": "Meeting starts at 3 PM today.",
      "time": "Fri",
      "unread": 1,
      "isGroup": true,
    },
    {
      "name": "Sara Malik",
      "message": "Got the project file, thanks!",
      "time": "Wed",
      "unread": 1,
      "isGroup": false,
    },
  ];

  List<Map<String, dynamic>> filteredConversations = [];

  @override
  void initState() {
    super.initState();
    filteredConversations = List.from(conversations);
    _searchController.addListener(_filterConversations);
  }

  void _filterConversations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredConversations = conversations
          .where((chat) => chat["name"].toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Messages",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8), // distance below AppBar
          child: SizedBox(),
        ),
      ),
      body: Column(
        children: [
          // 🔍 Search Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                hintText: "Search conversations...",
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // 💬 Conversation List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredConversations.length,
              itemBuilder: (context, index) {
                final chat = filteredConversations[index];
                final bool isGroup = chat["isGroup"];

                return Column(
                  children: [
                    ListTile(
                      leading: isGroup
                          ? _buildGroupIcon(chat["name"])
                          : _buildUserAvatar(chat["name"]),
                      title: Text(
                        chat["name"],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        chat["message"],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            chat["time"],
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          if (chat["unread"] > 0)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: blue,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                "${chat["unread"]}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              chatName: chat["name"],
                              isGroup: chat["isGroup"],
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, thickness: 0.4),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String name) {
    return CircleAvatar(
      backgroundColor: Colors.grey.shade300,
      radius: 25,
      child: Text(
        name[0],
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildGroupIcon(String name) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        name.split(' ').map((e) => e[0]).take(2).join(),
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }
}
