import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:studently/models/chat.dart';
import 'package:studently/logger.dart';

class ChatStorage {
  final Box _convBox;
  final Box _msgBox;

  static const _userNamesKey = 'user_names';
  static const _allConversationsKey = 'all_conversations';

  String _msgKey(String conversationId) => 'conv_$conversationId';

  ChatStorage(this._convBox, this._msgBox);

  // --- User Names ---
  Map<String, String> getCachedUserNames() {
    final cachedNames = _convBox.get(_userNamesKey);
    if (cachedNames != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(cachedNames);
        return decoded.map((key, value) => MapEntry(key, value.toString()));
      } catch (e) {
        logger.e('[ChatStorage] Error decoding user names: $e');
      }
    }
    return {};
  }

  void saveUserNames(Map<String, String> names) {
    _convBox.put(_userNamesKey, jsonEncode(names));
  }

  // --- Conversations ---
  List<ChatConversation> getCachedConversations() {
    final cachedData = _convBox.get(_allConversationsKey);
    if (cachedData != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((json) => ChatConversation.fromJson(json)).toList();
      } catch (e) {
        logger.e('[ChatStorage] Error decoding conversations: $e');
      }
    }
    return [];
  }

  void saveConversations(List<ChatConversation> conversations) {
    _convBox.put(
      _allConversationsKey,
      jsonEncode(conversations.map((e) => e.toJson()).toList()),
    );
  }

  // --- Messages ---
  List<ChatMessage> getCachedMessages(String conversationId) {
    final cachedData = _msgBox.get(_msgKey(conversationId));
    if (cachedData != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(cachedData);
        return decodedList.map((e) => ChatMessage.fromJson(e)).toList();
      } catch (e) {
        logger.e(
          '[ChatStorage] Error decoding messages for conv $conversationId: $e',
        );
      }
    }
    return [];
  }

  void saveMessages(String conversationId, List<ChatMessage> messages) {
    _msgBox.put(
      _msgKey(conversationId),
      jsonEncode(messages.map((e) => e.toJson()).toList()),
    );
  }
}
