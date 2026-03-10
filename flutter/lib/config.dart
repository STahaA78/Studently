class AppConfig {
  // static const String apiBaseUrl = "https://studentlybackend-production.up.railway.app";
  // static const String wsBaseUrl = "wss://studentlybackend-production.up.railway.app/ws";
  // static const String apiBaseUrl = "http://localhost:8000";
  // static const String wsBaseUrl = "ws://localhost:8000/ws";
  static const String ipAddress = "192.168.18.12"; 
  
  static const String apiBaseUrl = "http://$ipAddress:8000";
  static const String wsBaseUrl = "ws://$ipAddress:8000/ws";
}