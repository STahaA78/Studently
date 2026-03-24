import 'dart:convert';
import 'package:studently/models/chat.dart';
import 'package:studently/services/api.dart';
import 'package:studently/logger.dart';

class ChatRepository {
  final ApiService _apiService = ApiService();

  Future<List<ChatConversation>> getUserConversations() async {
    logger.d("[$runtimeType] Fetching conversations for current authenticated user");
    final response = await _apiService.get('/chat/conversations');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => ChatConversation.fromJson(json)).toList();
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    logger.d("[$runtimeType] Fetching messages for conversation: $conversationId");
    final response = await _apiService.get('/chat/$conversationId/messages');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => ChatMessage.fromJson(json)).toList();
  }

  Future<void> sendMessage({
    required String conversationId,
    required String text,
    List<String>? attachments,
  }) async {
    logger.d("[$runtimeType] Sending message to conversation: $conversationId");
    await _apiService.post(
      '/chat/send',
      body: {
        "conversation_id": conversationId,
        "text": text,
        "attachments": attachments ?? [],
      },
    );
  }

  Future<void> markChatAsRead(String conversationId) async {
    logger.d("[$runtimeType] Marking chat $conversationId as read");
    await _apiService.post('/chat/$conversationId/read');
  }

  Future<String> getUserName(String userId) async {
    final response = await _apiService.get('/users/$userId/profile');
    final data = jsonDecode(response.body);
    return data['name'] ?? "Student User";
  }

  Future<List<Map<String, String>>> getFriendsList() async {
    final response = await _apiService.get('/users/0/friends_list');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((f) => {
      "id": f['_id'].toString(),
      "Name": f['name'].toString()
    }).toList();
  }

  Future<String?> createOrGetConversation(String receiverId) async {
    final response = await _apiService.post('/chat/$receiverId/create_chat');
    final data = jsonDecode(response.body);
    return data['conversation_id'];
  }

  // Add this inside ChatRepository class
  Future<String?> joinCourseGroupChat(String courseId) async {
    logger.d("[$runtimeType] Joining group chat for course: $courseId");
    try {
      final response = await _apiService.post('/chat/course/$courseId/join');
      final data = jsonDecode(response.body);
      return data['conversation_id'];
    } catch (e) {
      logger.e("[$runtimeType] Error joining course chat: $e");
      return null;
    }
  }

  Future<String?> uploadAttachment(List<int> bytes, String filename) async {
    logger.i("ChatRepository: Initiating attachment upload...");
    try {
      // Pass bytes and filename to the API Gateway
      final response = await ApiService().uploadFile('/chat/upload', bytes, filename);
      
      final data = jsonDecode(response.body);
      final url = data['url'];
      
      logger.i("ChatRepository: Upload successful. URL: $url");
      return url;
      
    } catch (e) {
      logger.e("ChatRepository: Attachment upload failed: $e");
      return null;
    }
  }
}
