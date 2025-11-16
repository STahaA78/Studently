import 'package:flutter/material.dart';
import 'dart:math';

class ChatPage extends StatefulWidget {
  final String chatName;
  final bool isGroup;

  const ChatPage({
    super.key,
    required this.chatName,
    required this.isGroup,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final Color blue = const Color(0xFF1976D2);
  final Random random = Random();

  // Group members (for sample use)
  final List<String> groupMembers = ["Moiz", "Taha", "Sara", "Ali", "Fatima"];

  // Generate random color for each member
  late final Map<String, Color> memberColors = {
    for (var member in groupMembers)
      member: Colors.primaries[random.nextInt(Colors.primaries.length)].shade700
  };

  // Sample messages
  final List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();

    if (widget.isGroup) {
      messages.addAll([
        {
          "text": "Hey everyone, meeting at 3 PM today?",
          "sender": "Sara",
          "isMe": false,
          "time": "9:45 AM"
        },
        {
          "text": "Yes, that works for me!",
          "sender": "Moiz",
          "isMe": false,
          "time": "9:46 AM"
        },
        {
          "text": "I might be 5 mins late 😅",
          "sender": "Ali",
          "isMe": false,
          "time": "9:47 AM"
        },
        {
          "text": "No problem! I’ll join right on time.",
          "sender": "You",
          "isMe": true,
          "time": "9:48 AM"
        },
      ]);
    } else {
      messages.addAll([
        {
          "text":
              "Hi, just wanted to confirm if you're coming to the football match on Thursday.",
          "isMe": true,
          "time": "10:00 AM"
        },
        {
          "text": "Yes, I am! Let’s grab food after.",
          "isMe": false,
          "time": "10:05 AM"
        },
        {
          "text":
              "Perfect, see you there! Let’s discuss our project too if we get time.",
          "isMe": true,
          "time": "10:07 AM"
        },
      ]);
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({
        "text": text,
        "sender": widget.isGroup ? "You" : null,
        "isMe": true,
        "time": "Now",
      });
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0.3,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.chatName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          Icon(
            widget.isGroup ? Icons.groups_2_rounded : Icons.info_outline,
            color: Colors.black54,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final bool isMe = msg["isMe"];
                final bool showSender = widget.isGroup && !isMe;
                final String? sender = msg["sender"];

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        // Sender name for group chats
                        if (showSender && sender != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 6, bottom: 2),
                            child: Text(
                              sender,
                              style: TextStyle(
                                color: memberColors[sender],
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        // Message bubble
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? blue : Colors.grey.shade200,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(12),
                              topRight: const Radius.circular(12),
                              bottomLeft: Radius.circular(isMe ? 12 : 0),
                              bottomRight: Radius.circular(isMe ? 0 : 12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                msg["text"],
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                msg["time"],
                                style: TextStyle(
                                  color:
                                      isMe ? Colors.white70 : Colors.grey.shade600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Message input area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "Type your message...",
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send_rounded, color: blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
