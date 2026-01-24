import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:studently/models/chat_model.dart';
import 'package:studently/logger.dart'; 

class ChatService {
  static const String baseUrl = "http://127.0.0.1:8000/chat"; 

  Future<List<ChatConversation>> getUserConversations(String userId) async {
    logger.d("Fetching conversations for user: $userId");
    try {
      final response = await http.get(Uri.parse('$baseUrl/user/$userId'));

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        logger.i("Successfully fetched ${data.length} conversations");
        return data.map((json) => ChatConversation.fromJson(json)).toList();
      } else {
        logger.e("Failed to load chats: ${response.statusCode}");
        throw Exception("Failed to load chats: ${response.statusCode}");
      }
    } catch (e) {
      logger.e("Error fetching chats", error: e);
      throw Exception("Error fetching chats: $e");
    }
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    logger.d("Fetching messages for conversation: $conversationId");
    try {
      final response = await http.get(Uri.parse('$baseUrl/$conversationId/messages'));

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        logger.i("Successfully fetched ${data.length} messages");
        return data.map((json) => ChatMessage.fromJson(json)).toList();
      } else {
        logger.e("Failed to load messages: ${response.statusCode}");
        throw Exception("Failed to load messages: ${response.statusCode}");
      }
    } catch (e) {
      logger.e("Error fetching messages", error: e);
      throw Exception("Error fetching messages: $e");
    }
  }

  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    logger.d("Sending message from $senderId to $receiverId");
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send'),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "sender_id": senderId,
          "receiver_id": receiverId,
          "text": text,
          "attachments": [], 
        }),
      );

      if (response.statusCode == 200) {
        logger.i("Message sent successfully");
      } else {
        logger.e("Failed to send message: ${response.body}");
        throw Exception("Failed to send message: ${response.body}");
      }
    } catch (e) {
      logger.e("Error sending message", error: e);
      throw Exception("Error sending message: $e");
    }
  }

  // --- NEW METHOD ---
  Future<void> markChatAsRead(String conversationId, String userId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/$conversationId/read'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId}),
      );
    } catch (e) {
      logger.e("Error marking chat as read", error: e);
    }
  }
}