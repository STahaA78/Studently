import 'dart:convert';
import 'package:studently/models/chat.dart';
import 'package:studently/models/chat_info.dart';
import 'package:studently/services/api.dart';
import 'package:studently/logger.dart';

class ChatRepository {
  final ApiService _apiService = ApiService();

  Future<List<ChatConversation>> getUserConversations() async {
    logger.d(
      "[$runtimeType] Fetching conversations for current authenticated user",
    );
    final response = await _apiService.get('/chat/conversations');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => ChatConversation.fromJson(json)).toList();
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    logger.d(
      "[$runtimeType] Fetching messages for conversation: $conversationId",
    );
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

  Future<Map<String, String>> getUserProfileBasic(String userId) async {
    final response = await _apiService.get('/users/$userId/profile');
    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    final profile = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : data;
    return {
      'name': profile['name']?.toString() ?? "Student User",
      'picture': profile['picture']?.toString() ?? "",
    };
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
      final response = await ApiService().uploadFile(
        '/chat/upload',
        bytes,
        filename,
      );

      final data = jsonDecode(response.body);
      final url = data['url'];

      logger.i("ChatRepository: Upload successful. URL: $url");
      return url;
    } catch (e) {
      logger.e("ChatRepository: Attachment upload failed: $e");
      return null;
    }
  }

  // ========== CHAT INFO & DELETE METHODS ==========

  /// Soft delete a conversation for the current user
  /// The conversation is marked as deleted only for this user, not for others
  Future<void> deleteConversation(String conversationId) async {
    logger.d("[$runtimeType] Deleting conversation: $conversationId");
    try {
      await _apiService.post('/chat/$conversationId/delete');
    } catch (e) {
      logger.e("[$runtimeType] Error deleting conversation: $e");
      rethrow;
    }
  }

  /// Leave a group chat for the current user
  Future<void> leaveGroupChat(String conversationId) async {
    logger.d("[$runtimeType] Leaving group chat: $conversationId");
    try {
      await _apiService.post('/chat/$conversationId/leave');
    } catch (e) {
      logger.e("[$runtimeType] Error leaving group chat: $e");
      rethrow;
    }
  }

  /// Get full conversation details (including user info for DM or participant list for groups)
  Future<ChatInfoData> getChatInfo(String conversationId) async {
    logger.d("[$runtimeType] Fetching chat info for: $conversationId");
    try {
      final response = await _apiService.get('/chat/$conversationId/info');
      final data = jsonDecode(response.body);
      return ChatInfoData.fromJson(data);
    } catch (e) {
      logger.e("[$runtimeType] Error fetching chat info: $e");
      rethrow;
    }
  }

  /// Get group chat participants
  Future<List<ParticipantInfo>> getGroupParticipants(
      String conversationId) async {
    logger.d("[$runtimeType] Fetching participants for: $conversationId");
    try {
      final response =
          await _apiService.get('/chat/$conversationId/participants');
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ParticipantInfo.fromJson(json)).toList();
    } catch (e) {
      logger.e("[$runtimeType] Error fetching participants: $e");
      rethrow;
    }
  }

  /// Get conversation statistics (message count, dates, etc.)
  Future<Map<String, dynamic>> getConversationStats(
      String conversationId) async {
    logger.d("[$runtimeType] Fetching stats for: $conversationId");
    try {
      final response =
          await _apiService.get('/chat/$conversationId/stats');
      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : {};
    } catch (e) {
      logger.e("[$runtimeType] Error fetching stats: $e");
      return {};
    }
  }

  /// Clear all messages in a conversation for current user
  Future<void> clearChatMessages(String conversationId) async {
    logger.d("[$runtimeType] Clearing messages for: $conversationId");
    try {
      await _apiService.post('/chat/$conversationId/clear');
    } catch (e) {
      logger.e("[$runtimeType] Error clearing messages: $e");
      rethrow;
    }
  }
}
