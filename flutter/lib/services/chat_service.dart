import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:studently/models/chat_model.dart';
import 'package:studently/logger.dart'; 
import 'package:studently/auth_service.dart'; 

class ChatService {
  static const String baseUrl = "http://127.0.0.1:8000/chat"; 

  // Helper to get headers with the JWT token
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await authService.value.getIdToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  /// UPDATE: userId is no longer needed in the parameter!
  Future<List<ChatConversation>> getUserConversations() async {
    logger.d("[$runtimeType] Fetching conversations for current authenticated user");
    try {
      final headers = await _getAuthHeaders();
      
      // Note: We removed /user/$userId from the URL
      final response = await http.get(
        Uri.parse('$baseUrl/conversations'), 
        headers: headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        logger.i("[$runtimeType] Successfully fetched ${data.length} conversations");
        return data.map((json) => ChatConversation.fromJson(json)).toList();
      } else {
        logger.e("[$runtimeType] Failed to load chats: ${response.statusCode}");
        throw Exception("Failed to load chats: ${response.statusCode}");
      }
    } catch (e) {
      logger.e("[$runtimeType] Error fetching chats", error: e);
      throw Exception("Error fetching chats: $e");
    }
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    logger.d("[$runtimeType] Fetching messages for conversation: $conversationId");
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/$conversationId/messages'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        logger.i("[$runtimeType] Successfully fetched ${data.length} messages");
        return data.map((json) => ChatMessage.fromJson(json)).toList();
      } else {
        logger.e("[$runtimeType] Failed to load messages: ${response.statusCode}");
        throw Exception("Failed to load messages: ${response.statusCode}");
      }
    } catch (e) {
      logger.e("[$runtimeType] Error fetching messages", error: e);
      throw Exception("Error fetching messages: $e");
    }
  }

  /// UPDATE: senderId is removed from parameters as the backend knows who is sending
  Future<void> sendMessage({
    required String receiverId,
    required String text,
  }) async {
    logger.d("[$runtimeType] Sending message to $receiverId");
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/send'),
        headers: headers,
        body: jsonEncode({
          // sender_id is extracted from the JWT on the backend
          "receiver_id": receiverId,
          "text": text,
          "attachments": [], 
        }),
      );

      if (response.statusCode == 200) {
        logger.i("[$runtimeType] Message sent successfully");
      } else {
        logger.e("[$runtimeType] Failed to send message: ${response.body}");
        throw Exception("Failed to send message: ${response.body}");
      }
    } catch (e) {
      logger.e("[$runtimeType] Error sending message", error: e);
      throw Exception("Error sending message: $e");
    }
  }

  /// UPDATE: userId removed from parameters
  Future<void> markChatAsRead(String conversationId) async {
    logger.d("[$runtimeType] Marking chat $conversationId as read");
    try {
      final headers = await _getAuthHeaders();
      await http.post(
        Uri.parse('$baseUrl/$conversationId/read'),
        headers: headers,
        // No body needed if backend uses the token to identify the user
      );
    } catch (e) {
      logger.e("[$runtimeType] Error marking chat as read", error: e);
    }
  }

  Future<String> getUserName(String userId) async {
    try {
      final headers = await _getAuthHeaders();
      // Using a users base URL here - adjust if your route prefix is different
      final response = await http.get(
        Uri.parse("http://127.0.0.1:8000/users/$userId/info"), 
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['full_name'] ?? "Student User";
      }
      return "Student User";
    } catch (e) {
      logger.e("Error fetching username", error: e);
      return "Student User";
    }
  }
  Future<List<Map<String, String>>> getFriendsList() async {
    try {
      final headers = await _getAuthHeaders();
      // Assuming user routes are on port 8000
      final response = await http.get(
        Uri.parse("http://127.0.0.1:8000/users/friends_list"), 
        headers: headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((f) => {
          "id": f['id'].toString(),
          "Name": f['Name'].toString()
        }).toList();
      }
      return [];
    } catch (e) {
      logger.e("Error fetching friends list", error: e);
      return [];
    }
  }

  Future<String?> createOrGetConversation(String receiverId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse("$baseUrl/$receiverId/create_chat"),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['conversation_id'];
      }
      return null;
    } catch (e) {
      logger.e("Error creating conversation", error: e);
      return null;
    }
  }
}
