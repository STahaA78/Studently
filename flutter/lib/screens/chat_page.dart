import 'dart:async'; // For Timer
import 'package:flutter/material.dart';
import 'package:studently/models/chat_model.dart';
import 'package:studently/services/chat_service.dart';
import 'package:studently/utils/colors.dart'; // Ensure you have this or use the hardcoded Color(0xFF1976D2)

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String currentUserId;
  final String otherUserId;
  final String otherUserName; // Added to display name in AppBar

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    required this.otherUserId,
    this.otherUserName = "Chat", // Default fallback
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // Backend Service
  final ChatService _chatService = ChatService();
  
  // UI Controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Styles
  final Color blue = const Color(0xFF1976D2); // Keeping your blue color

  // State Variables
  List<ChatMessage> _messages = [];
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    
    // --- NEW: Mark as read immediately on open ---
    _chatService.markChatAsRead(widget.conversationId, widget.currentUserId);

    // Poll for new messages every 3 seconds
    _timer = Timer.periodic(Duration(seconds: 3), (timer) {
      _fetchMessages(isBackgroundRefresh: true);
      // --- NEW: Keep marking as read while page is open ---
      _chatService.markChatAsRead(widget.conversationId, widget.currentUserId);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool isBackgroundRefresh = false}) async {
    try {
      final messages = await _chatService.getMessages(widget.conversationId);
      
      if (mounted) {
        setState(() {
          _messages = messages;
          if (!isBackgroundRefresh) _isLoading = false;
        });
        
        // Scroll to bottom on initial load
        if (!isBackgroundRefresh) _scrollToBottom();
      }
    } catch (e) {
      print("Error loading messages: $e");
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

    _messageController.clear(); // Clear immediately for better UX

    try {
      await _chatService.sendMessage(
        senderId: widget.currentUserId,
        receiverId: widget.otherUserId,
        text: text,
      );
      // Refresh immediately
      _fetchMessages(isBackgroundRefresh: true);
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send: $e")),
      );
    }
  }

  // Helper to format timestamps (e.g. "10:30 AM")
  String _formatTime(String timestamp) {
    try {
       // Assuming timestamp is ISO string from backend
       final DateTime dt = DateTime.parse(timestamp).toLocal(); 
       final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
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
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.otherUserName, // Display the friend's name (or ID)
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          const Icon(
            Icons.info_outline,
            color: Colors.black54,
          ),
          const SizedBox(width: 10),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(8), 
          child: SizedBox(),
        ),
      ),
      body: Column(
        children: [
          // Chat messages
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
                        final bool isMe = msg.senderId == widget.currentUserId;

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
                                        msg.text,
                                        style: TextStyle(
                                          color: isMe ? Colors.white : Colors.black87,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTime(msg.timestamp),
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