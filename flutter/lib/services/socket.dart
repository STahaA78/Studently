import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:studently/auth_service.dart';
import 'package:studently/logger.dart';

class SocketService {
  WebSocketChannel? _channel;
  Stream? _broadcastStream;
  bool _isConnected = false;

  Future<void> connect() async {
    if (_isConnected) return; // Prevent multiple connections

    try {
      final token = await authService.value.getIdToken();
      if (token == null) return;

      final wsUrl = Uri.parse("ws://127.0.0.1:8000/ws/$token");
      _channel = WebSocketChannel.connect(wsUrl);
      
      // Broadcast stream allows both ChatPage and DirectMessagesPage to listen
      _broadcastStream = _channel!.stream.asBroadcastStream();
      _isConnected = true;
      logger.i("[SocketService] Connected to WebSocket");
    } catch (e) {
      logger.e("[SocketService] WebSocket connection failed", error: e);
    }
  }

  Stream? get stream => _broadcastStream;

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
    logger.i("[SocketService] Disconnected from WebSocket");
  }
}

// Global instance
final socketService = SocketService();