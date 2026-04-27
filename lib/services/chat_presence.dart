class ChatPresence {
  static String? activeConversationId;

  static void setActiveConversation(String? conversationId) {
    activeConversationId = conversationId;
  }
}
