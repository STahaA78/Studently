import 'dart:async';
import 'package:studently/config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:studently/logger.dart';

class SocketService {
  static final String _baseUrl = AppConfig.wsBaseUrl;
  WebSocketChannel? _channel;
  
  
  final StreamController<dynamic> _streamController = StreamController<dynamic>.broadcast();
  
  bool _isConnected = false;
  bool _isIntentionalDisconnect = false;
  Timer? _reconnectTimer;

  Future<void> connect() async {
    if (_isConnected) return; // Prevent multiple connections

    _isIntentionalDisconnect = false;

    try {
      final token = await authService.value.getIdToken();
      if (token == null) {
        logger.w("[SocketService] No auth token found. Cannot connect.");
        return;
      }

      final wsUrl = Uri.parse("$_baseUrl/$token");
      _channel = WebSocketChannel.connect(wsUrl);
      _isConnected = true;
      logger.i("[SocketService] Connected to WebSocket");

      // Listen to the live channel and forward incoming messages to our broadcast controller
      _channel!.stream.listen(
        (message) {
          _streamController.add(message);
        },
        onDone: () {
          logger.w("[SocketService] WebSocket Closed.");
          _isConnected = false;
          _handleUnexpectedDisconnect();
        },
        onError: (error) {
          logger.e("[SocketService] WebSocket Error", error: error);
          _isConnected = false;
          _handleUnexpectedDisconnect();
        },
      );
    } catch (e) {
      logger.e("[SocketService] WebSocket connection failed", error: e);
      _isConnected = false;
      _handleUnexpectedDisconnect();
    }
  }

  // UI Pages will call `socketService.stream` to listen for messages
  Stream get stream => _streamController.stream;

  void disconnect() {
    logger.i("[SocketService] Intentional disconnect.");
    _isIntentionalDisconnect = true;
    _reconnectTimer?.cancel();
    
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  void _handleUnexpectedDisconnect() {
    _channel = null; // Clear the dead channel

    // If the user navigated away and called disconnect(), stop here.
    if (_isIntentionalDisconnect) return;

    // Otherwise, it was an accidental drop. Reboot in 3 seconds.
    logger.i("[SocketService] Unexpected drop. Reconnecting in 3 seconds...");
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      connect();
    });
  }

  
}

// Global instance
final socketService = SocketService();