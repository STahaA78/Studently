import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:studently/models/chat.dart';
import 'package:studently/repositories/chat.dart';
import 'package:studently/services/socket.dart'; 
import 'package:studently/services/firebase_auth.dart'; 

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String otherUserId; // Will be "GROUP" for academic group chats
  final String otherUserName; // Displays the Course Name or Friend Name

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    this.otherUserName = "Chat",
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Color blue = const Color(0xFF1976D2);

  List<ChatMessage> _messages = [];
  StreamSubscription? _socketSubscription; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    
    // Initial mark as read
    ChatRepository().markChatAsRead(widget.conversationId);

    // REAL-TIME: Listen for new messages via WebSocket
    _socketSubscription = socketService.stream?.listen((event) {
      final payload = jsonDecode(event);
      
      // Only refresh if the incoming message belongs to THIS specific chat room
      if (payload['type'] == 'NEW_MESSAGE' && 
          payload['data']['conversation_id'] == widget.conversationId) {
        
        _fetchMessages(isBackgroundRefresh: true);
        ChatRepository().markChatAsRead(widget.conversationId);
      }
    });
  }

  @override
  void dispose() {
    _socketSubscription?.cancel(); 
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool isBackgroundRefresh = false}) async {
    try {
      final messages = await ChatRepository().getMessages(widget.conversationId);
      
      if (mounted) {
        setState(() {
          _messages = messages;
          if (!isBackgroundRefresh) _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Error loading messages: $e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await ChatRepository().sendMessage(
        conversationId: widget.conversationId,
        text: text,
      );
      
      _fetchMessages(isBackgroundRefresh: true);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send: $e")),
        );
      }
    }
  }

  String _formatTime(String timestamp) {
    try {
       final DateTime dt = DateTime.parse(timestamp).toLocal(); 
       final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
       final period = dt.hour >= 12 ? "PM" : "AM";
       final minute = dt.minute.toString().padLeft(2, '0');
       return "$hour:$minute $period";
    } catch (e) {
       return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.otherUserName, // This displays the full Course Name
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 18)
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : _messages.isEmpty 
                  ? const Center(child: Text("No messages yet. Say Hi!"))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final bool isMe = msg.senderId == authService.value.currentUser?.uid;

                        return _buildMessageBubble(msg, isMe);
                      },
                    ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    // Check if this is a group chat
    final bool isGroupChat = widget.otherUserId == "GROUP";

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
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
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // NEW: Display User Name if it's a Group Chat and not the current user
            if (isGroupChat && !isMe) 
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  msg.senderName, // Uses the name fetched from the database
                  style: TextStyle(
                    color: blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            Text(
              msg.text, 
              style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15)
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(msg.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey.shade600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 14),
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
    );
  }
}